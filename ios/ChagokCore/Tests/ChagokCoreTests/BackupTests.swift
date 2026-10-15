import XCTest
@testable import ChagokCore
final class BackupTests: XCTestCase {
    func sample() -> Snapshot { var s = Snapshot(); let a = Activity(name:"독서",metric:.pages,date:"2026-10-01"); s.activities = [a]; var e = Entry(activity:a,date:"2026-10-01",timezone:"UTC"); e.amount = 15; s.entries = [e]; s.onboarded = true; return s }
    func testJSONZIPAndConflictRoundtrip() throws {
        var s = sample(); let image = Data([1,2,3]); let hash = Archive.hash(image); s.attachments = [Attachment(hash:hash,name:"test.png",mime:"image/png")]
        let zip = try Backup.zip(s,images:[hash:image]); let p = try Backup.preview(zip,current:Snapshot()); XCTAssertTrue(p.missing.isEmpty)
        XCTAssertEqual(try Backup.merge(p,into:Snapshot(),replace:[]),s)
        let repeated = try Backup.preview(zip,current:s); XCTAssertTrue(repeated.conflicts.isEmpty)
        var changed = s; changed.entries[0].amount = 30
        let conflict = try Backup.preview(Backup.json(changed),current:s); XCTAssertEqual(conflict.conflicts,[s.entries[0].id]); XCTAssertEqual(conflict.missing.count,1)
        XCTAssertEqual(try Backup.merge(conflict,into:s,replace:[]).entries[0].amount,15)
        XCTAssertEqual(try Backup.merge(conflict,into:s,replace:[s.entries[0].id]).entries[0].amount,30)
    }
    func testRejectCorruptionAndUnsafePaths() throws {
        XCTAssertThrowsError(try Archive.zip(["../escape":Data()]))
        var data = try Archive.zip(["records.json":Data("abc".utf8)]); data[42] ^= 1
        XCTAssertThrowsError(try Archive.unzip(data)); XCTAssertThrowsError(try Archive.unzip(Data([1,2])))
    }
    func testLegacyPreservesUnknownAndDoesNotInventPages() throws {
        let root:[String:Any] = ["format":"chagok","version":1,"entities":[
            ["id":"reading","type":"activity","name":"독서","kind":"reading","schedule":[["effective":"2026-10-01","value":["type":"daily","start":"2026-10-01"]]]],
            ["id":"entry","type":"entry","activityId":"reading","date":"2026-10-02","done":true,"definition":["id":"reading","name":"독서","kind":"reading"],"data":["seconds":1200,"lastPage":55,"book":"책"]],
            ["id":"draft","type":"draft","text":"원문 보존"]]]
        let data = try JSONSerialization.data(withJSONObject:root); let p = try Backup.preview(data,current:Snapshot()); XCTAssertNil(p.state.entries[0].amount); XCTAssertEqual(p.state.entries[0].seconds,1200); XCTAssertNotNil(p.state.legacyEntities["draft"]); XCTAssertEqual(Progress.totalXP(p.state),0)
        let repeated = try Backup.preview(data,current:p.state); XCTAssertTrue(repeated.conflicts.isEmpty)
    }
    func testNRCUnitsMissingConflicts() {
        let a = RunningOCR.parse("3.1\nmiles\n30:00\nTime\n155\nAverage heart rate\n172\nCadence")
        XCTAssertEqual(a.distance!,4.9889664,accuracy:0.0001); XCTAssertEqual(a.seconds,1800); XCTAssertEqual(a.heartRate,155)
        let b = RunningOCR.parse("5.2 km\n시간 32:00"); XCTAssertNil(RunningOCR.merge([a,b]).distance); XCTAssertNil(b.cadence)
    }
}
