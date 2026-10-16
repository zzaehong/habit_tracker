import Foundation

public enum Day {
  private static var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  public static func date(_ day: String) -> Date? {
    let parts = day.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }
  public static func valid(_ day: String) -> Bool {
    guard let date = date(day) else { return false }
    return string(date, zone: "UTC") == day
  }
  public static func string(_ date: Date, zone: String) -> String {
    let f = DateFormatter()
    f.calendar = calendar
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: zone)
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }
  public static func add(_ day: String, _ count: Int) -> String {
    guard let d = date(day), let result = calendar.date(byAdding: .day, value: count, to: d) else {
      return day
    }
    return string(result, zone: "UTC")
  }
  public static func weekday(_ day: String) -> Int {
    date(day).map { calendar.component(.weekday, from: $0) } ?? 1
  }
  public static func week(_ day: String) -> String { add(day, -((weekday(day) + 5) % 7)) }
  public static func distance(_ from: String, _ to: String) -> Int {
    guard let a = date(from), let b = date(to) else { return 0 }
    return calendar.dateComponents([.day], from: a, to: b).day ?? 0
  }
  public static func range(_ from: String, _ to: String) -> [String] {
    guard valid(from), valid(to), from <= to else { return [] }
    return (0...min(distance(from, to), 36525)).map { add(from, $0) }
  }
}
public struct DailyProgress: Equatable, Sendable {
  public var amount: Double?
  public var stages: Int
  public var xp: Int
  public var satisfied: Bool { stages > 0 }
}
public struct Practice: Equatable, Sendable {
  public var achieved = 0
  public var expected = 0
  public var currentStreak = 0
  public var bestStreak = 0
  public var rate: Double? { expected == 0 ? nil : Double(achieved) / Double(expected) }
}
public enum Progress {
  public static func due(_ activity: Activity, _ day: String) -> Bool {
    guard let r = activity.rule(on: day), r.enabled, day >= r.start else { return false }
    switch r.schedule {
    case .daily: return true
    case .weekdays: return r.weekdays.contains(Day.weekday(day))
    case .weekly: return true
    case .interval: return Day.distance(r.start, day) % r.interval == 0
    case .once: return day == r.start
    }
  }
  public static func daily(
    _ activity: Activity, _ day: String, _ entries: [Entry], rewardOnly: Bool = false
  ) -> DailyProgress {
    guard let r = activity.rule(on: day) else {
      return DailyProgress(amount: nil, stages: 0, xp: 0)
    }
    let relevant = entries.filter {
      $0.activityID == activity.id && $0.date == day && (!rewardOnly || $0.rewardEligible)
    }
    let values = relevant.compactMap(\.amount)
    let total = values.isEmpty ? nil : values.reduce(0, +)
    let measured = r.thresholds.filter { (total ?? -1) >= $0 }.count
    let stages = max(measured, relevant.contains(where: \.confirmedMinimum) ? 1 : 0)
    let legacySuccess = !rewardOnly && relevant.contains(where: { $0.legacyDone == true })
    return DailyProgress(
      amount: total, stages: max(stages, legacySuccess ? 1 : 0),
      xp: stages == 0 ? 0 : 10 + (stages - 1) * 5)
  }
  public static func totalXP(_ state: Snapshot) -> Int {
    state.activities.reduce(0) { result, a in
      result
        + Set(state.entries.filter { $0.activityID == a.id && $0.rewardEligible }.map(\.date))
        .reduce(0) { $0 + daily(a, $1, state.entries, rewardOnly: true).xp }
    }
  }
  public static func level(_ xp: Int) -> (level: Int, earned: Int, required: Int) {
    var level = 1
    var remaining = max(0, xp)
    while remaining >= level * 100 {
      remaining -= level * 100
      level += 1
    }
    return (level, remaining, level * 100)
  }
  public static func practice(
    _ activity: Activity, entries: [Entry], from: String, through: String, today: String
  ) -> Practice {
    var result = Practice()
    var streak = 0
    var seenWeeks = Set<String>()
    for day in Day.range(from, min(through, today)) {
      guard let rule = activity.rule(on: day), rule.enabled, day >= rule.start else { continue }
      if rule.schedule == .weekly {
        let week = Day.week(day)
        guard seenWeeks.insert(week).inserted else { continue }
        let end = Day.add(week, 6)
        guard end < today && end <= through else { continue }
        // Partial first weeks are shown as progress, not failed weekly obligations.
        guard rule.start <= week, rule.effective <= week, from <= week else { continue }
        let successes = Day.range(week, end).filter { daily(activity, $0, entries).satisfied }.count
        result.expected += rule.weeklyCount
        result.achieved += min(successes, rule.weeklyCount)
        streak = successes >= rule.weeklyCount ? streak + 1 : 0
      } else {
        guard due(activity, day) else { continue }
        let success = daily(activity, day, entries).satisfied
        if day == today {
          if success && rule.schedule != .once { streak += 1 }
          continue
        }
        result.expected += 1
        if success { result.achieved += 1 }
        if rule.schedule != .once { streak = success ? streak + 1 : 0 }
      }
      result.bestStreak = max(result.bestStreak, streak)
    }
    result.currentStreak = streak
    result.bestStreak = max(result.bestStreak, streak)
    return result
  }
  public static func bookPosition(_ book: String, entries: [Entry]) -> (last: Int?, furthest: Int?)
  {
    let relevant = entries.filter { $0.bookID == book && $0.lastPage != nil }.sorted {
      $0.date < $1.date
    }
    return (relevant.last?.lastPage, relevant.compactMap(\.lastPage).max())
  }
  public static func customAggregate(_ field: CustomField, entries: [Entry]) -> Double? {
    let values = entries.compactMap { entry -> Double? in
      guard let definition = entry.definition.fields.first(where: { $0.id == field.id }),
        definition.unit == field.unit, definition.kind == .number
      else { return nil }
      return entry.fields[field.id].flatMap(Double.init)
    }
    guard !values.isEmpty else { return nil }
    let total = values.reduce(0, +)
    return field.aggregate == .sum ? total : total / Double(values.count)
  }
}
