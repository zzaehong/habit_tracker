import Foundation

public struct BackupDocument: Codable, Sendable {
  public var format = "chagok-ios"
  public var version = 2
  public var state: Snapshot
  public init(state: Snapshot) { self.state = state }
}
public struct ImportPreview: Sendable {
  public var state: Snapshot
  public var files: [String: Data]
  public var conflicts: [String]
  public var missing: [String]
  public var legacy: Bool
}
public enum Backup {
  public static func json(_ state: Snapshot) throws -> Data {
    try state.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    return try encoder.encode(BackupDocument(state: state))
  }
  public static func zip(_ state: Snapshot, images: [String: Data]) throws -> Data {
    var files = ["records.json": try json(state)]
    for attachment in state.attachments {
      guard let data = images[attachment.hash], Archive.hash(data) == attachment.hash else {
        throw AppError.invalid("원본이 없는 이미지가 있습니다. JSON은 내보낼 수 있습니다.")
      }
      files["attachments/" + attachment.hash] = data
    }
    return try Archive.zip(files)
  }
  public static func preview(_ data: Data, current: Snapshot) throws -> ImportPreview {
    guard data.count <= Archive.limit else { throw AppError.invalid("가져오기 한도는 300MB입니다.") }
    let files = data.starts(with: [0x50, 0x4b]) ? try Archive.unzip(data) : [:]
    let json = files.isEmpty ? data : (files["records.json"] ?? Data())
    guard let root = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
      throw AppError.invalid("백업 형식이 올바르지 않습니다.")
    }
    let legacy = root["format"] as? String == "chagok"
    var imported: Snapshot
    if legacy {
      imported = try LegacyImport.convert(root)
    } else {
      let doc = try JSONDecoder().decode(BackupDocument.self, from: json)
      guard doc.format == "chagok-ios", doc.version == 2 else {
        throw AppError.invalid("지원하지 않는 백업입니다.")
      }
      imported = doc.state
    }
    try imported.validate()
    var missing: [String] = []
    for attachment in imported.attachments {
      if let blob = files["attachments/" + attachment.hash] {
        guard Archive.hash(blob) == attachment.hash else {
          throw AppError.invalid("이미지 해시 검증에 실패했습니다.")
        }
      } else {
        missing.append(attachment.name)
      }
    }
    let conflicts =
      conflicts(current.activities, imported.activities)
      + conflicts(current.entries, imported.entries) + conflicts(current.books, imported.books)
      + conflicts(current.attachments, imported.attachments)
      + imported.legacyEntities.keys.filter {
        current.legacyEntities[$0] != nil
          && current.legacyEntities[$0] != imported.legacyEntities[$0]
      }.map { "legacy:" + $0 }
    imported.onboarded = true
    return ImportPreview(
      state: imported, files: files, conflicts: conflicts, missing: missing, legacy: legacy)
  }
  private static func conflicts<T: Identifiable & Equatable>(_ current: [T], _ incoming: [T])
    -> [String] where T.ID == String
  {
    incoming.compactMap { item in
      current.contains(where: { $0.id == item.id && $0 != item }) ? item.id : nil
    }
  }
  public static func merge(_ preview: ImportPreview, into current: Snapshot, replace: Set<String>)
    throws -> Snapshot
  {
    var result = current
    func merged<T: Identifiable>(_ old: [T], _ new: [T]) -> [T] where T.ID == String {
      var items = old
      for item in new {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
          if replace.contains(item.id) { items[index] = item }
        } else {
          items.append(item)
        }
      }
      return items
    }
    result.activities = merged(current.activities, preview.state.activities)
    result.entries = merged(current.entries, preview.state.entries)
    result.books = merged(current.books, preview.state.books)
    result.attachments = merged(current.attachments, preview.state.attachments)
    for (id, raw) in preview.state.legacyEntities
    where result.legacyEntities[id] == nil || replace.contains("legacy:" + id) {
      result.legacyEntities[id] = raw
    }
    if current.activities.isEmpty && current.entries.isEmpty {
      result.timezone = preview.state.timezone
      result.zoneChanges = preview.state.zoneChanges
      result.showRewards = preview.state.showRewards
      result.timer = preview.state.timer
    }
    result.onboarded = true
    try result.validate()
    return result
  }
}
public enum LegacyImport {
  public static func convert(_ root: [String: Any]) throws -> Snapshot {
    guard root["version"] as? Int == 1, let entities = root["entities"] as? [[String: Any]] else {
      throw AppError.invalid("기존 차곡 v1 백업이 아닙니다.")
    }
    var result = Snapshot()
    result.timezone = "Asia/Seoul"
    var ids = Set<String>()
    for entity in entities {
      guard let id = entity["id"] as? String, ids.insert(id).inserted else {
        throw AppError.invalid("기존 백업에 중복 ID가 있습니다.")
      }
      let raw = try JSONSerialization.data(withJSONObject: entity, options: [.sortedKeys])
      result.legacyEntities[id] = String(decoding: raw, as: UTF8.self)
    }
    for entity in entities where entity["type"] as? String == "activity" {
      result.activities.append(activity(entity))
    }
    // Records contain definition snapshots even if an old filtered export omitted the activity.
    for entity in entities
    where entity["type"] as? String == "entry" && entity["deleted"] as? Bool != true {
      guard let id = entity["id"] as? String, let activityID = entity["activityId"] as? String,
        let day = entity["date"] as? String, let data = entity["data"] as? [String: Any],
        let definition = entity["definition"] as? [String: Any]
      else { throw AppError.invalid("기존 기록 필수 항목이 없습니다.") }
      if !result.activities.contains(where: { $0.id == activityID }) {
        result.activities.append(activity(definition))
      }
      guard let a = result.activities.first(where: { $0.id == activityID }) else {
        throw AppError.invalid("기존 기록 활동을 찾을 수 없습니다.")
      }
      var entry = Entry(
        activity: a, date: day, timezone: entity["timezone"] as? String ?? "Asia/Seoul")
      entry.definition = activity(definition)
      entry.id = id
      entry.rewardEligible = false
      entry.legacyDone = entity["done"] as? Bool
      entry.legacyJSON = result.legacyEntities[id]
      entry.note = data["note"] as? String ?? ""
      entry.seconds = data["seconds"] as? Double
      switch definition["kind"] as? String {
      case "reading":
        entry.startPage = data["startPage"] as? Int
        entry.lastPage = data["lastPage"] as? Int
        entry.readingMode = "range"
        if let start = entry.startPage, let last = entry.lastPage, last >= start {
          entry.amount = Double(last - start)
        } else if let start = entry.startPage, let last = entry.lastPage, last < start {
          entry.startPage = nil
        }
        if let title = data["book"] as? String, !title.isEmpty {
          let bookID = "legacy-book-" + Archive.hash(Data(title.utf8))
          if !result.books.contains(where: { $0.id == bookID }) {
            var book = Book(title: title)
            book.id = bookID
            result.books.append(book)
          }
          entry.bookID = bookID
        }
      case "running": entry.amount = data["distance"] as? Double
      case "study": entry.amount = entry.seconds
      case "check": entry.amount = nil
      default: break
      }
      entry.intensity = data["intensity"] as? Double
      entry.heartRate = data["heartRate"] as? Double
      entry.cadence = data["cadence"] as? Double
      entry.reportedPace = data["reportedPace"] as? Double
      entry.attachments = entity["attachments"] as? [String] ?? []
      if let custom = data["custom"] as? [String: Any] {
        entry.fields = custom.mapValues { String(describing: $0) }
      }
      result.entries.append(entry)
    }
    for e in entities where e["type"] as? String == "attachment" && e["deleted"] as? Bool != true {
      guard let id = e["id"] as? String, let hash = e["hash"] as? String else {
        throw AppError.invalid("첨부 정보가 올바르지 않습니다.")
      }
      result.attachments.append(
        Attachment(
          id: id, hash: hash, name: e["name"] as? String ?? "이전 이미지",
          mime: e["mime"] as? String ?? "image/png"))
    }
    result.onboarded = true
    return result
  }
  private static func activity(_ e: [String: Any]) -> Activity {
    let kind = e["kind"] as? String ?? "check"
    let metric: Metric =
      kind == "reading"
      ? .pages : kind == "running" ? .distance : kind == "study" ? .time : .completion
    let schedule = e["schedule"] as? [[String: Any]] ?? []
    var a = Activity(
      name: e["name"] as? String ?? "이전 활동", metric: metric,
      date: schedule.first?["effective"] as? String ?? "1970-01-01")
    a.id = e["id"] as? String ?? UUID().uuidString
    a.running = kind == "running"
    a.archived = e["deleted"] as? Bool == true || e["enabled"] as? Bool == false
    a.rules = schedule.enumerated().map { index, item in
      let v = item["value"] as? [String: Any] ?? [:]
      var r = Rule(
        effective: item["effective"] as? String ?? "1970-01-01", thresholds: metric.defaults)
      r.id = "legacy-rule-\(a.id)-\(index)"
      r.start = v["start"] as? String ?? r.effective
      r.schedule = ScheduleKind(rawValue: v["type"] as? String ?? "daily") ?? .daily
      r.weekdays = (v["weekdays"] as? [Int] ?? [1, 2, 3, 4, 5]).map { $0 + 1 }
      r.weeklyCount = v["count"] as? Int ?? 3
      r.interval = v["interval"] as? Int ?? 2
      r.enabled = item["enabled"] as? Bool ?? true
      return r
    }
    if a.rules.isEmpty {
      var r = Rule(effective: "1970-01-01", thresholds: metric.defaults)
      r.id = "legacy-rule-\(a.id)-0"
      a.rules = [r]
    }
    a.fields = (e["fields"] as? [[String: Any]] ?? []).map { f in
      var field = CustomField(
        name: f["name"] as? String ?? "항목",
        kind: f["type"] as? String == "number"
          ? .number : f["type"] as? String == "select" ? .choice : .text)
      field.id = f["id"] as? String ?? UUID().uuidString
      field.unit = f["unit"] as? String ?? ""
      field.options = f["options"] as? [String] ?? []
      field.aggregate = f["aggregate"] as? String == "mean" ? .mean : .sum
      field.hidden = f["hidden"] as? Bool ?? false
      return field
    }
    return a
  }
}
