import XCTest

@testable import ChagokCore

final class BackupTests: XCTestCase {
  func sample() -> Snapshot {
    var s = Snapshot()
    let a = Activity(name: "독서", metric: .pages, date: "2026-10-01")
    s.activities = [a]
    var e = Entry(activity: a, date: "2026-10-01", timezone: "UTC")
    e.amount = 15
    s.entries = [e]
    s.onboarded = true
    return s
  }
  func testJSONZIPAndConflictRoundtrip() throws {
    var s = sample()
    let image = Data([1, 2, 3])
    let hash = Archive.hash(image)
    s.attachments = [Attachment(hash: hash, name: "test.png", mime: "image/png")]
    let zip = try Backup.zip(s, images: [hash: image])
    let p = try Backup.preview(zip, current: Snapshot())
    XCTAssertTrue(p.missing.isEmpty)
    XCTAssertEqual(try Backup.merge(p, into: Snapshot(), replace: []), s)
    let repeated = try Backup.preview(zip, current: s)
    XCTAssertTrue(repeated.conflicts.isEmpty)
    var changed = s
    changed.entries[0].amount = 30
    let conflict = try Backup.preview(Backup.json(changed), current: s)
    XCTAssertEqual(conflict.conflicts, [s.entries[0].id])
    XCTAssertEqual(conflict.missing.count, 1)
    XCTAssertEqual(try Backup.merge(conflict, into: s, replace: []).entries[0].amount, 15)
    XCTAssertEqual(
      try Backup.merge(conflict, into: s, replace: [s.entries[0].id]).entries[0].amount, 30)
  }
  func testDeflatedWebCompatibleZIP() throws {
    let data = Data(
      base64Encoded:
        "UEsDBBQAAAAIAAQIUF0dzQvKFAAAABIAAAAMAAAAcmVjb3Jkcy5qc29uq1bKSM3JyVeyUnqzYcWrzQuVagFQSwMEFAAAAAgABAhQXQAAAAACAAAAAAAAAAkAAABlbXB0eS50eHQDAFBLAQIUAxQAAAAIAAQIUF0dzQvKFAAAABIAAAAMAAAAAAAAAAAAAACAAQAAAAByZWNvcmRzLmpzb25QSwECFAMUAAAACAAECFBdAAAAAAIAAAAAAAAACQAAAAAAAAAAAAAAgAE+AAAAZW1wdHkudHh0UEsFBgAAAAACAAIAcQAAAGcAAAAAAA=="
    )!
    let files = try Archive.unzip(data)
    XCTAssertEqual(String(data: files["records.json"]!, encoding: .utf8), "{\"hello\":\"차곡\"}")
    XCTAssertEqual(files["empty.txt"], Data())
  }
  func testRejectCorruptionAndUnsafePaths() throws {
    XCTAssertThrowsError(try Archive.zip(["../escape": Data()]))
    var data = try Archive.zip(["records.json": Data("abc".utf8)])
    data[42] ^= 1
    XCTAssertThrowsError(try Archive.unzip(data))
    XCTAssertThrowsError(try Archive.unzip(Data([1, 2])))
  }
  func testLegacyPreservesUnknownAndDoesNotInventPages() throws {
    let root: [String: Any] = [
      "format": "chagok", "version": 1,
      "entities": [
        [
          "id": "reading", "type": "activity", "name": "독서", "kind": "reading",
          "schedule": [
            ["effective": "2026-10-01", "value": ["type": "daily", "start": "2026-10-01"]]
          ],
        ],
        [
          "id": "entry", "type": "entry", "activityId": "reading", "date": "2026-10-02",
          "done": true, "definition": ["id": "reading", "name": "독서", "kind": "reading"],
          "data": ["seconds": 1200, "lastPage": 55, "book": "책"],
        ],
        ["id": "draft", "type": "draft", "text": "원문 보존"],
      ],
    ]
    let data = try JSONSerialization.data(withJSONObject: root)
    let p = try Backup.preview(data, current: Snapshot())
    XCTAssertNil(p.state.entries[0].amount)
    XCTAssertEqual(p.state.entries[0].seconds, 1200)
    XCTAssertNotNil(p.state.legacyEntities["draft"])
    XCTAssertEqual(Progress.totalXP(p.state), 0)
    let repeated = try Backup.preview(data, current: p.state)
    XCTAssertTrue(repeated.conflicts.isEmpty)
  }
  func testNRCUnitsMissingConflicts() {
    let a = RunningOCR.parse("3.1\nmiles\n30:00\nTime\n155\nAverage heart rate\n172\nCadence")
    XCTAssertEqual(a.distance!, 4.9889664, accuracy: 0.0001)
    XCTAssertEqual(a.seconds, 1800)
    XCTAssertEqual(a.heartRate, 155)
    let b = RunningOCR.parse("5.2 km\n시간 32:00")
    XCTAssertNil(RunningOCR.merge([a, b]).distance)
    XCTAssertNil(b.cadence)
  }
  func testTimerAndTimezoneBackupAndInvalidReferences() throws {
    var s = Snapshot()
    s.timezone = "Asia/Seoul"
    let a = Activity(name: "공부", metric: .time, date: "2026-10-01")
    s.activities = [a]
    s.timer = TimerState(
      activityID: a.id, date: "2026-10-01", now: Date(timeIntervalSince1970: 100))
    s.zoneChanges = [ZoneChange(effective: "2026-10-02", zone: "America/New_York")]
    let p = try Backup.preview(Backup.json(s), current: Snapshot())
    XCTAssertEqual(p.state.timer, s.timer)
    XCTAssertEqual(p.state.zoneChanges, s.zoneChanges)
    s.timer!.activityID = "missing"
    XCTAssertThrowsError(try s.validate())
  }
  func testLegacyDetailedActivitiesAndImageRoundtrip() throws {
    let image = Data([137, 80, 78, 71, 1, 2])
    let hash = Archive.hash(image)
    var entities: [[String: Any]] = []
    for kind in ["weights", "meal", "tutoring"] {
      let definition: [String: Any] = [
        "id": kind, "type": "activity", "name": kind, "kind": kind,
        "schedule": [
          ["effective": "2026-10-01", "value": ["type": "daily", "start": "2026-10-01"]]
        ],
      ]
      entities.append(definition)
      entities.append([
        "id": kind + "-entry", "type": "entry", "activityId": kind, "date": "2026-10-02",
        "done": true, "definition": definition, "attachments": ["image"],
        "data": [
          "sets": [["exercise": "스쿼트", "kg": 60, "reps": 8, "done": true]], "menu": "고정 메뉴",
          "kcal": 400, "alias": "학생 A", "subject": "수학",
        ],
      ])
    }
    entities.append([
      "id": "image", "type": "attachment", "hash": hash, "name": "캡처", "mime": "image/png",
    ])
    entities.append([
      "id": "draft", "type": "draft", "text": "원문", "ocr": "OCR 원문", "attachments": ["image"],
    ])
    let json = try JSONSerialization.data(withJSONObject: [
      "format": "chagok", "version": 1, "entities": entities,
    ])
    let oldZIP = try Archive.zip(["records.json": json, "attachments/" + hash: image])
    let p = try Backup.preview(oldZIP, current: Snapshot())
    XCTAssertEqual(p.state.entries.count, 3)
    XCTAssertEqual(p.state.legacyEntities.count, 8)
    XCTAssertTrue(p.missing.isEmpty)
    XCTAssertTrue(p.state.entries.allSatisfy { $0.legacyJSON?.contains("스쿼트") == true })
    let newZIP = try Backup.zip(p.state, images: [hash: image])
    let restored = try Backup.preview(newZIP, current: Snapshot())
    XCTAssertEqual(restored.state, p.state)
    XCTAssertEqual(restored.files["attachments/" + hash], image)
  }

}
