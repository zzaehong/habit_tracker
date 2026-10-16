import ChagokCore
import Foundation
import Observation
import SwiftData
import UserNotifications

@Model final class StoredSnapshot {
  @Attribute(.unique) var key: String
  var schemaVersion: Int
  var payload: Data
  init(payload: Data) {
    key = "main"
    schemaVersion = 2
    self.payload = payload
  }
}
@MainActor @Observable final class AppStore {
  private(set) var state = Snapshot()
  var error: String?
  var toast: String?
  private let context: ModelContext
  private let folder: URL
  private var row: StoredSnapshot?
  private(set) var loaded = false
  private var remindersReady = false
  private var reminderTask: Task<Void, Never>?
  init(context: ModelContext) {
    self.context = context
    context.autosaveEnabled = false
    folder = URL.applicationSupportDirectory.appending(
      path: "ChagokImages", directoryHint: .isDirectory)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let rows = try context.fetch(FetchDescriptor<StoredSnapshot>())
      if let saved = rows.first {
        guard saved.schemaVersion == 2 else { throw AppError.invalid("지원하지 않는 저장소 버전입니다.") }
        row = saved
        state = try JSONDecoder().decode(Snapshot.self, from: saved.payload)
        try state.validate()
      }
      loaded = true
      Task {
        await migrateReminders()
        remindersReady = true
        refreshReminders()
      }
    } catch {
      self.error = "기록을 열지 못했습니다. 데이터를 삭제하지 말고 앱을 다시 열어 주세요. \(error.localizedDescription)"
    }
  }
  @discardableResult func update(_ change: (inout Snapshot) throws -> Void) -> Bool {
    guard loaded else {
      error = "저장소가 열리지 않았습니다."
      return false
    }
    do {
      var next = state
      try change(&next)
      try next.validate()
      let data = try JSONEncoder().encode(next)
      let record = row ?? StoredSnapshot(payload: data)
      if row == nil { context.insert(record) }
      record.payload = data
      do { try context.save() } catch {
        context.rollback()
        throw error
      }
      row = record
      state = next
      refreshReminders()
      return true
    } catch {
      self.error = "저장하지 못했습니다: \(error.localizedDescription)"
      return false
    }
  }
  private func migrateReminders() async {
    let center = UNUserNotificationCenter.current()
    let requests = await center.pendingNotificationRequests()
    guard !UserDefaults.standard.bool(forKey: "activityRemindersMigrated") else { return }
    let migrated = update { snapshot in
      for index in snapshot.activities.indices
      where snapshot.activities[index].reminderMinute == nil {
        let id = snapshot.activities[index].id
        if let request = requests.first(where: { $0.identifier.hasPrefix(id + "|") }),
          let trigger = request.trigger as? UNCalendarNotificationTrigger,
          let hour = trigger.dateComponents.hour, let minute = trigger.dateComponents.minute
        {
          snapshot.activities[index].reminderMinute = hour * 60 + minute
        }
      }
    }
    if migrated { UserDefaults.standard.set(true, forKey: "activityRemindersMigrated") }
  }
  func refreshReminders() {
    guard remindersReady else { return }
    // Serialize replacements so a slow earlier update cannot restore stale reminders.
    let previous = reminderTask
    let snapshot = state
    let enabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    reminderTask = Task {
      await previous?.value
      let center = UNUserNotificationCenter.current()
      center.removeAllPendingNotificationRequests()
      guard enabled else { return }
      let status = await center.notificationSettings().authorizationStatus
      guard status == .authorized || status == .provisional else { return }
      do {
        for plan in Progress.reminders(snapshot, now: .now) {
          let content = UNMutableNotificationContent()
          content.title = "작은 실천을 차곡"
          content.body = "\(plan.name), 내 속도로 시작해 볼까요?"
          content.sound = .default
          var calendar = Calendar(identifier: .gregorian)
          calendar.timeZone = TimeZone(identifier: snapshot.activeZone()) ?? .current
          var parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: plan.date)
          parts.timeZone = calendar.timeZone
          try await center.add(
            UNNotificationRequest(
              identifier: plan.id, content: content,
              trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
      } catch { self.error = "알림 예약 실패: \(error.localizedDescription)" }
    }
  }
  func save(_ entry: Entry, book: Book? = nil) -> Bool {
    update { s in
      try entry.validate()
      if let book, !s.books.contains(where: { $0.id == book.id }) { s.books.append(book) }
      if let i = s.entries.firstIndex(where: { $0.id == entry.id }) {
        s.entries[i] = entry
      } else {
        s.entries.append(entry)
      }
    }
  }
  func quick(_ a: Activity, day: String) -> String? {
    if Progress.daily(a, day, state.entries).satisfied { return nil }
    var entry = Entry(activity: a, date: day, timezone: state.activeZone())
    entry.confirmedMinimum = true
    if save(entry) {
      toast = "최소 달성으로 기록했어요. 측정값은 비워 두었어요."
      return entry.id
    }
    return nil
  }
  func remove(_ id: String) { _ = update { $0.entries.removeAll { $0.id == id } } }
  func image(_ hash: String) -> Data? {
    guard hash.count == 64, hash.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
    return try? Data(contentsOf: folder.appending(path: hash))
  }
  func addImages(_ images: [(Data, String, String)]) throws -> [Attachment] {
    var attachments: [Attachment] = []
    for (data, name, mime) in images {
      guard data.count <= 10 * 1024 * 1024 else { throw AppError.invalid("이미지는 장당 10MB까지입니다.") }
      let hash = Archive.hash(data)
      let a =
        state.attachments.first(where: { $0.hash == hash })
        ?? Attachment(hash: hash, name: name, mime: mime)
      try data.write(to: folder.appending(path: hash), options: .atomic)
      attachments.append(a)
    }
    guard
      update({ s in
        for a in attachments where !s.attachments.contains(where: { $0.id == a.id }) {
          s.attachments.append(a)
        }
      })
    else { throw AppError.invalid("첨부 정보 저장 실패") }
    return attachments
  }
  func deleteAttachment(_ id: String) {
    guard let a = state.attachments.first(where: { $0.id == id }) else { return }
    guard
      update({ s in
        s.attachments.removeAll { $0.id == id }
        for i in s.entries.indices { s.entries[i].attachments.removeAll { $0 == id } }
      })
    else { return }
    if !state.attachments.contains(where: { $0.hash == a.hash }) {
      do { try FileManager.default.removeItem(at: folder.appending(path: a.hash)) } catch {
        self.error = "원본 파일 정리 실패: \(error.localizedDescription)"
      }
    }
  }
  func importBackup(_ preview: ImportPreview, replace: Set<String>) -> Bool {
    do {
      let merged = try Backup.merge(preview, into: state, replace: replace)
      for a in preview.state.attachments {
        if let bytes = preview.files["attachments/" + a.hash] {
          try bytes.write(to: folder.appending(path: a.hash), options: .atomic)
        }
      }
      return update { $0 = merged }
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  func export(zip: Bool) throws -> URL {
    let data: Data
    if zip {
      var images: [String: Data] = [:]
      for a in state.attachments { images[a.hash] = image(a.hash) }
      data = try Backup.zip(state, images: images)
    } else {
      data = try Backup.json(state)
    }
    let url = URL.temporaryDirectory.appending(path: "차곡-\(state.today()).\(zip ? "zip" : "json")")
    try data.write(to: url, options: .atomic)
    return url
  }
}
