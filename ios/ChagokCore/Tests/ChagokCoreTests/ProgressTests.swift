import XCTest
@testable import ChagokCore
final class ProgressTests: XCTestCase {
    func testQuickCompletionDoesNotInventPagesOrStack() throws {
        let a = Activity(name:"독서",metric:.pages,date:"2026-10-01")
        var e = Entry(activity:a,date:"2026-10-01",timezone:"Asia/Seoul"); e.confirmedMinimum = true
        let p = Progress.daily(a,e.date,[e,e]); XCTAssertNil(p.amount); XCTAssertEqual(p.xp,10)
        e.amount = 15; XCTAssertEqual(Progress.daily(a,e.date,[e]).xp,15)
    }
    func testSplitAndOrderInvariantAndDeleteRecalculation() {
        let a = Activity(name:"독서",metric:.pages,date:"2026-10-01")
        var e = Entry(activity:a,date:"2026-10-01",timezone:"Asia/Seoul"); e.amount = 10
        var f = e; f.id = "second"; f.amount = 5
        XCTAssertEqual(Progress.daily(a,e.date,[e,f]),Progress.daily(a,e.date,[f,e]))
        XCTAssertEqual(Progress.daily(a,e.date,[e,f]).xp,15); XCTAssertEqual(Progress.daily(a,e.date,[e]).xp,10)
    }
    func testScheduleStreakAndOpenDay() {
        var a = Activity(name:"독서",metric:.pages,date:"2026-10-05"); a.rules[0].schedule = .weekdays; a.rules[0].weekdays = [2,3,5,6]
        let entries = ["2026-10-05","2026-10-06","2026-10-08"].map { d in var e = Entry(activity:a,date:d,timezone:"Asia/Seoul"); e.amount = 5; return e }
        let p = Progress.practice(a,entries:entries,from:"2026-10-05",through:"2026-10-09",today:"2026-10-09")
        XCTAssertEqual(p.currentStreak,3); XCTAssertEqual(p.expected,3)
        XCTAssertEqual(Progress.practice(a,entries:entries,from:"2026-10-05",through:"2026-10-10",today:"2026-10-10").currentStreak,0)
    }
    func testWeeklyUniqueDatesAndOpenWeek() {
        var a = Activity(name:"러닝",metric:.distance,date:"2026-10-05"); a.rules[0].schedule = .weekly; a.rules[0].weeklyCount = 2
        var e = Entry(activity:a,date:"2026-10-05",timezone:"Asia/Seoul"); e.amount = 3
        XCTAssertEqual(Progress.practice(a,entries:[e,e],from:"2026-10-05",through:"2026-10-12",today:"2026-10-12").achieved,1)
        XCTAssertEqual(Progress.practice(a,entries:[e],from:"2026-10-05",through:"2026-10-08",today:"2026-10-08").expected,0)
    }
    func testHistoricalRulesAndLegacyXP() {
        var a = Activity(name:"독서",metric:.pages,date:"2026-10-01"); a.rules.append(Rule(effective:"2026-10-10",thresholds:[20]))
        var e = Entry(activity:a,date:"2026-10-02",timezone:"Asia/Seoul"); e.amount = 5; e.rewardEligible = false; e.legacyDone = true
        var s = Snapshot(); s.activities = [a]; s.entries = [e]
        XCTAssertEqual(Progress.totalXP(s),0); XCTAssertTrue(Progress.daily(a,e.date,[e]).satisfied)
        s.entries[0].rewardEligible = true; XCTAssertEqual(Progress.totalXP(s),10)
    }
    func testDateValidationTimerAndBookReread() throws {
        XCTAssertFalse(Day.valid("2026-02-30")); XCTAssertTrue(Day.valid("2028-02-29"))
        let start = Date(timeIntervalSince1970:100); var timer = TimerState(activityID:"a",date:"2026-10-01",now:start)
        timer.pause(at:start.addingTimeInterval(30)); timer.resume(at:start.addingTimeInterval(60)); XCTAssertEqual(timer.elapsed(at:start.addingTimeInterval(90)),60)
        let a = Activity(name:"독서",metric:.pages,date:"2026-10-01"); var e = Entry(activity:a,date:"2026-10-01",timezone:"UTC"); e.bookID = "b"; e.lastPage = 55; e.startPage = 40; e.amount = 15
        var f = e; f.id = "next"; f.date = "2026-10-02"; f.startPage = 10; f.lastPage = 20; f.amount = 10
        XCTAssertEqual(Progress.bookPosition("b",entries:[e,f]).furthest,55); XCTAssertEqual(Progress.bookPosition("b",entries:[e,f]).last,20)
        try e.validate(); f.lastPage = 5; XCTAssertThrowsError(try f.validate())
    }
}
