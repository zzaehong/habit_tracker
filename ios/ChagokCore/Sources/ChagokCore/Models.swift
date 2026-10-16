import Foundation

public enum AppError: LocalizedError, Equatable {
  case invalid(String)
  public var errorDescription: String? {
    if case .invalid(let text) = self { return text }
    return nil
  }
}
public enum Metric: String, Codable, CaseIterable, Sendable {
  case pages, distance, time, count, completion
  public var title: String {
    switch self {
    case .pages: "페이지"
    case .distance: "거리"
    case .time: "시간"
    case .count: "횟수"
    case .completion: "완료"
    }
  }
  public var unit: String {
    switch self {
    case .pages: "쪽"
    case .distance: "km"
    case .time: "분"
    case .count: "회"
    case .completion: "회"
    }
  }
  public func display(_ value: Double) -> String {
    (self == .time ? value / 60 : value).formatted(.number.precision(.fractionLength(0...2)))
  }
  public var defaults: [Double] {
    switch self {
    case .pages: [5, 15, 30]
    case .distance: [1, 3, 5]
    case .time: [600, 1800, 3600]
    case .count: [1, 5, 10]
    case .completion: [1]
    }
  }
}
public enum FieldKind: String, Codable, CaseIterable, Sendable { case number, text, choice }
public enum Aggregate: String, Codable, CaseIterable, Sendable { case sum, mean }
public struct CustomField: Codable, Equatable, Identifiable, Sendable {
  public var id = UUID().uuidString
  public var name: String
  public var kind: FieldKind
  public var unit = ""
  public var options: [String] = []
  public var aggregate: Aggregate = .sum
  public var hidden = false
  public init(name: String, kind: FieldKind) {
    self.name = name
    self.kind = kind
  }
}
public enum ScheduleKind: String, Codable, CaseIterable, Sendable {
  case daily, weekdays, weekly, interval, once
  public var title: String {
    switch self {
    case .daily: "매일"
    case .weekdays: "요일 지정"
    case .weekly: "주 N회"
    case .interval: "N일 간격"
    case .once: "날짜 지정"
    }
  }
}
public struct Rule: Codable, Equatable, Identifiable, Sendable {
  public var id = UUID().uuidString
  public var effective: String
  public var start: String
  public var schedule: ScheduleKind = .daily
  public var weekdays = [2, 3, 4, 5, 6]  // Calendar Sunday = 1
  public var weeklyCount = 3
  public var interval = 2
  public var thresholds: [Double]
  public var enabled = true
  public init(effective: String, thresholds: [Double]) {
    self.effective = effective
    self.start = effective
    self.thresholds = thresholds
  }
  public func validate(metric: Metric) throws {
    guard Day.valid(effective), Day.valid(start), (1...7).contains(weeklyCount), interval > 0,
      !thresholds.isEmpty, thresholds.count <= 3, thresholds.allSatisfy({ $0.isFinite && $0 > 0 }),
      zip(thresholds, thresholds.dropFirst()).allSatisfy({ $0 < $1 }),
      weekdays.allSatisfy({ (1...7).contains($0) })
    else { throw AppError.invalid("일정과 오름차순 체크포인트를 확인하세요.") }
    if schedule == .weekdays && weekdays.isEmpty { throw AppError.invalid("요일을 하나 이상 선택하세요.") }
    if metric == .completion && thresholds != [1] { throw AppError.invalid("완료형 기준은 1회입니다.") }
    if [.pages, .count].contains(metric) && thresholds.contains(where: { $0.rounded() != $0 }) {
      throw AppError.invalid("페이지와 횟수는 정수로 입력하세요.")
    }
  }
}
public struct Activity: Codable, Equatable, Identifiable, Sendable {
  public var id = UUID().uuidString
  public var name: String
  public var icon = "leaf"
  public var metric: Metric
  public var fields: [CustomField] = []
  public var rules: [Rule]
  public var archived = false
  public var running = false
  public init(name: String, metric: Metric, date: String) {
    self.name = name
    self.metric = metric
    self.rules = [Rule(effective: date, thresholds: metric.defaults)]
  }
  public func rule(on date: String) -> Rule? {
    rules.filter { $0.effective <= date }.sorted { $0.effective < $1.effective }.last
  }
  public func validate() throws {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !rules.isEmpty,
      Set(rules.map(\.effective)).count == rules.count, Set(fields.map(\.id)).count == fields.count
    else { throw AppError.invalid("활동 이름과 정의를 확인하세요.") }
    for rule in rules { try rule.validate(metric: metric) }
    for f in fields {
      guard !f.name.isEmpty,
        f.kind != .choice || (!f.options.isEmpty && Set(f.options).count == f.options.count)
      else { throw AppError.invalid("추가 항목의 이름과 선택지를 확인하세요.") }
    }
  }
}
public struct Entry: Codable, Equatable, Identifiable, Sendable {
  public var id = UUID().uuidString
  public var activityID: String
  public var date: String
  public var timezone: String
  public var definition: Activity
  public var ruleID: String?
  public var amount: Double?
  public var confirmedMinimum = false
  public var legacyDone: Bool? = nil
  public var rewardEligible = true
  public var note = ""
  public var fields: [String: String] = [:]
  public var bookID: String?
  public var startPage: Int?
  public var lastPage: Int?
  public var readingMode = "direct"
  public var seconds: Double?
  public var intensity: Double?
  public var heartRate: Double?
  public var cadence: Double?
  public var reportedPace: Double?
  public var attachments: [String] = []
  public var ocrText: String?
  public var legacyJSON: String?
  public init(activity: Activity, date: String, timezone: String) {
    self.activityID = activity.id
    self.definition = activity
    self.date = date
    self.timezone = timezone
    self.ruleID = activity.rule(on: date)?.id
  }
  public func validate() throws {
    guard Day.valid(date), TimeZone(identifier: timezone) != nil else {
      throw AppError.invalid("날짜·시간대를 확인하세요.")
    }
    if let amount {
      guard amount.isFinite, amount >= 0,
        ![Metric.pages, .count, .completion].contains(definition.metric)
          || amount.rounded() == amount
      else { throw AppError.invalid("측정값을 확인하세요.") }
    }
    for value in [seconds, intensity, heartRate, cadence, reportedPace].compactMap({ $0 }) {
      guard value.isFinite && value >= 0 else { throw AppError.invalid("상세 수치를 확인하세요.") }
    }
    if let intensity, !(1...10).contains(intensity) { throw AppError.invalid("체감 강도는 1–10입니다.") }
    if let startPage, let lastPage, lastPage < startPage {
      throw AppError.invalid("다시 읽기는 새 시작 페이지를 지정하세요.")
    }
    if (startPage ?? 0) < 0 || (lastPage ?? 0) < 0 { throw AppError.invalid("페이지는 0 이상입니다.") }
    for field in definition.fields where !field.hidden {
      guard let value = fields[field.id], !value.isEmpty else { continue }
      if field.kind == .number && (Double(value) == nil || !Double(value)!.isFinite) {
        throw AppError.invalid("\(field.name): 숫자를 입력하세요.")
      }
      if field.kind == .choice && !field.options.contains(value) {
        throw AppError.invalid("\(field.name): 선택지를 확인하세요.")
      }
    }
  }
}
public struct Book: Codable, Equatable, Identifiable, Sendable {
  public var id = UUID().uuidString
  public var title: String
  public init(title: String) { self.title = title }
}
public struct Attachment: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var hash: String
  public var name: String
  public var mime: String
  public init(id: String = UUID().uuidString, hash: String, name: String, mime: String) {
    self.id = id
    self.hash = hash
    self.name = name
    self.mime = mime
  }
}
public struct TimerState: Codable, Equatable, Sendable {
  public var activityID: String
  public var date: String
  public var startedAt: Date?
  public var accumulated: Double = 0
  public init(activityID: String, date: String, now: Date = .now) {
    self.activityID = activityID
    self.date = date
    self.startedAt = now
  }
  public func elapsed(at now: Date) -> Double {
    max(0, accumulated + (startedAt.map { now.timeIntervalSince($0) } ?? 0))
  }
  public mutating func pause(at now: Date) {
    accumulated = elapsed(at: now)
    startedAt = nil
  }
  public mutating func resume(at now: Date) { startedAt = now }
}
public struct ZoneChange: Codable, Equatable, Sendable {
  public var effective: String
  public var zone: String
  public init(effective: String, zone: String) {
    self.effective = effective
    self.zone = zone
  }
}
public struct Snapshot: Codable, Equatable, Sendable {
  public var version = 2
  public var activities: [Activity] = []
  public var entries: [Entry] = []
  public var books: [Book] = []
  public var attachments: [Attachment] = []
  public var legacyEntities: [String: String] = [:]
  public var timer: TimerState?
  public var timezone = TimeZone.current.identifier
  public var zoneChanges: [ZoneChange] = []
  public var onboarded = false
  public var showRewards = true
  public init() {}
  public func today(now: Date = .now) -> String { Day.string(now, zone: activeZone(now: now)) }
  public func activeZone(now: Date = .now) -> String {
    var current = timezone
    for change in zoneChanges.sorted(by: { $0.effective < $1.effective }) {
      guard change.effective <= Day.string(now, zone: current) else { break }
      current = change.zone
    }
    return current
  }
  public func validate() throws {
    guard version == 2, TimeZone(identifier: timezone) != nil else {
      throw AppError.invalid("지원하지 않는 백업 버전 또는 시간대입니다.")
    }
    guard Set(activities.map(\.id)).count == activities.count,
      Set(entries.map(\.id)).count == entries.count,
      Set(attachments.map(\.id)).count == attachments.count,
      Set(books.map(\.id)).count == books.count
    else { throw AppError.invalid("중복 ID가 있습니다.") }
    let allIDs = activities.map(\.id) + entries.map(\.id) + books.map(\.id) + attachments.map(\.id)
    guard allIDs.allSatisfy({ !$0.isEmpty }), Set(allIDs).count == allIDs.count else {
      throw AppError.invalid("엔티티 ID가 충돌합니다.")
    }
    guard
      zoneChanges.allSatisfy({ Day.valid($0.effective) && TimeZone(identifier: $0.zone) != nil }),
      Set(zoneChanges.map(\.effective)).count == zoneChanges.count
    else { throw AppError.invalid("시간대 변경 이력을 확인하세요.") }
    if let timer {
      guard activities.contains(where: { $0.id == timer.activityID && $0.metric == .time }),
        Day.valid(timer.date), timer.accumulated.isFinite, timer.accumulated >= 0
      else { throw AppError.invalid("타이머 상태가 올바르지 않습니다.") }
    }
    for a in activities { try a.validate() }
    for e in entries {
      try e.validate()
      guard
        activities.contains(where: { $0.id == e.activityID && $0.metric == e.definition.metric }),
        e.definition.id == e.activityID
      else {
        throw AppError.invalid("기록의 활동이 없습니다.")
      }
    }
    for a in attachments {
      guard a.hash.count == 64, a.hash.allSatisfy({ "0123456789abcdef".contains($0) }) else {
        throw AppError.invalid("이미지 해시가 올바르지 않습니다.")
      }
    }
  }
}
