import XCTest

@testable import ChagokCore

final class ProgressTests: XCTestCase {
  func testQuickCompletionDoesNotInventPagesOrStack() throws {
    let a = Activity(name: "독서", metric: .pages, date: "2026-10-01")
    var e = Entry(activity: a, date: "2026-10-01", timezone: "Asia/Seoul")
    e.confirmedMinimum = true
    let p = Progress.daily(a, e.date, [e, e])
    XCTAssertNil(p.amount)
    XCTAssertEqual(p.xp, 10)
    e.amount = 15
    XCTAssertEqual(Progress.daily(a, e.date, [e]).xp, 15)
  }
  func testSplitAndOrderInvariantAndDeleteRecalculation() {
    let a = Activity(name: "독서", metric: .pages, date: "2026-10-01")
    var e = Entry(activity: a, date: "2026-10-01", timezone: "Asia/Seoul")
    e.amount = 10
    var f = e
    f.id = "second"
    f.amount = 5
    XCTAssertEqual(Progress.daily(a, e.date, [e, f]), Progress.daily(a, e.date, [f, e]))
    XCTAssertEqual(Progress.daily(a, e.date, [e, f]).xp, 15)
    XCTAssertEqual(Progress.daily(a, e.date, [e]).xp, 10)
  }
  func testScheduleStreakAndOpenDay() {
    var a = Activity(name: "독서", metric: .pages, date: "2026-10-05")
    a.rules[0].schedule = .weekdays
    a.rules[0].weekdays = [2, 3, 5, 6]
    let entries = ["2026-10-05", "2026-10-06", "2026-10-08"].map { d in
      var e = Entry(activity: a, date: d, timezone: "Asia/Seoul")
      e.amount = 5
      return e
    }
    let p = Progress.practice(
      a, entries: entries, from: "2026-10-05", through: "2026-10-09", today: "2026-10-09")
    XCTAssertEqual(p.currentStreak, 3)
    XCTAssertEqual(p.expected, 3)
    XCTAssertEqual(
      Progress.practice(
        a, entries: entries, from: "2026-10-05", through: "2026-10-10", today: "2026-10-10"
      ).currentStreak, 0)
  }
  func testWeeklyUniqueDatesAndOpenWeek() {
    var a = Activity(name: "러닝", metric: .distance, date: "2026-10-05")
    a.rules[0].schedule = .weekly
    a.rules[0].weeklyCount = 2
    var e = Entry(activity: a, date: "2026-10-05", timezone: "Asia/Seoul")
    e.amount = 3
    XCTAssertEqual(
      Progress.practice(
        a, entries: [e, e], from: "2026-10-05", through: "2026-10-12", today: "2026-10-12"
      ).achieved, 1)
    XCTAssertEqual(
      Progress.practice(
        a, entries: [e], from: "2026-10-05", through: "2026-10-08", today: "2026-10-08"
      ).expected, 0)
  }
  func testHistoricalRulesAndLegacyXP() {
    var a = Activity(name: "독서", metric: .pages, date: "2026-10-01")
    a.rules.append(Rule(effective: "2026-10-10", thresholds: [20]))
    var e = Entry(activity: a, date: "2026-10-02", timezone: "Asia/Seoul")
    e.amount = 5
    e.rewardEligible = false
    e.legacyDone = true
    var s = Snapshot()
    s.activities = [a]
    s.entries = [e]
    XCTAssertEqual(Progress.totalXP(s), 0)
    XCTAssertTrue(Progress.daily(a, e.date, [e]).satisfied)
    s.entries[0].rewardEligible = true
    XCTAssertEqual(Progress.totalXP(s), 10)
  }
  func testDateValidationTimerAndBookReread() throws {
    XCTAssertFalse(Day.valid("2026-02-30"))
    XCTAssertTrue(Day.valid("2028-02-29"))
    let start = Date(timeIntervalSince1970: 100)
    var timer = TimerState(activityID: "a", date: "2026-10-01", now: start)
    timer.pause(at: start.addingTimeInterval(30))
    timer.resume(at: start.addingTimeInterval(60))
    XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(90)), 60)
    let a = Activity(name: "독서", metric: .pages, date: "2026-10-01")
    var e = Entry(activity: a, date: "2026-10-01", timezone: "UTC")
    e.bookID = "b"
    e.lastPage = 55
    e.startPage = 40
    e.amount = 15
    var f = e
    f.id = "next"
    f.date = "2026-10-02"
    f.startPage = 10
    f.lastPage = 20
    f.amount = 10
    XCTAssertEqual(Progress.bookPosition("b", entries: [e, f]).furthest, 55)
    XCTAssertEqual(Progress.bookPosition("b", entries: [e, f]).last, 20)
    try e.validate()
    f.lastPage = 5
    XCTAssertThrowsError(try f.validate())
  }
  func testCustomFieldSnapshotUnitsAndMissingValues() throws {
    var a = Activity(name: "공부", metric: .time, date: "2026-10-01")
    var field = CustomField(name: "문제 수", kind: .number)
    field.unit = "개"
    a.fields = [field]
    var e = Entry(activity: a, date: "2026-10-02", timezone: "Asia/Seoul")
    e.fields[field.id] = "12"
    try e.validate()
    XCTAssertEqual(Progress.customAggregate(field, entries: [e]), 12)
    field.unit = "쪽"
    XCTAssertNil(Progress.customAggregate(field, entries: [e]))
    e.fields[a.fields[0].id] = "문자"
    XCTAssertThrowsError(try e.validate())
  }
  func testIntervalOnceAndPausePreservePast() {
    var a = Activity(name: "활동", metric: .completion, date: "2026-10-01")
    a.rules[0].schedule = .interval
    a.rules[0].interval = 3
    XCTAssertTrue(Progress.due(a, "2026-10-04"))
    XCTAssertFalse(Progress.due(a, "2026-10-05"))
    var paused = a.rules[0]
    paused.id = "pause"
    paused.effective = "2026-10-06"
    paused.enabled = false
    a.rules.append(paused)
    XCTAssertTrue(Progress.due(a, "2026-10-04"))
    XCTAssertFalse(Progress.due(a, "2026-10-07"))
    var once = Activity(name: "한 번", metric: .completion, date: "2026-10-01")
    once.rules[0].schedule = .once
    var e = Entry(activity: once, date: "2026-10-02", timezone: "UTC")
    e.confirmedMinimum = true
    let p = Progress.practice(
      once, entries: [e], from: "2026-10-01", through: "2026-10-03", today: "2026-10-03")
    XCTAssertEqual(p.achieved, 0)
    XCTAssertEqual(p.expected, 1)
    XCTAssertEqual(p.currentStreak, 0)
  }
  func testRuleValidationAndRewardCap() throws {
    var a = Activity(name: "러닝", metric: .distance, date: "2026-10-01")
    var e = Entry(activity: a, date: "2026-10-01", timezone: "UTC")
    e.amount = 100
    XCTAssertEqual(Progress.daily(a, e.date, [e]).xp, 20)
    a.rules[0].thresholds = [5, 3]
    XCTAssertThrowsError(try a.validate())
    XCTAssertEqual(Progress.level(300).level, 3)
  }

  func testSuccessiveTimezoneChangesActivateAtCurrentZoneMidnight() {
    var s = Snapshot()
    s.timezone = "Asia/Seoul"
    s.zoneChanges = [
      ZoneChange(effective: "2026-10-02", zone: "America/New_York"),
      ZoneChange(effective: "2026-10-04", zone: "Asia/Tokyo"),
    ]
    let parser = ISO8601DateFormatter()
    XCTAssertEqual(
      s.activeZone(now: parser.date(from: "2026-10-04T01:00:00Z")!), "America/New_York")
    XCTAssertEqual(s.activeZone(now: parser.date(from: "2026-10-04T05:00:00Z")!), "Asia/Tokyo")
  }

}
