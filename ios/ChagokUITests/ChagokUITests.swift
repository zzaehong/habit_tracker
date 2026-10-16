import XCTest

final class ChagokUITests: XCTestCase {
  @MainActor func testCreateActivityFromSettingsAndValidationFeedback() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    app.buttons["template-pages"].tap()
    app.buttons["activity-save"].tap()
    app.buttons["onboarding-finish"].tap()
    app.tabBars.buttons["설정"].tap()
    app.buttons["활동 만들기"].tap()
    app.buttons["activity-save"].tap()
    XCTAssertTrue(app.alerts["저장할 수 없어요"].waitForExistence(timeout: 3))
    app.alerts.buttons["확인"].tap()
    let name = app.textFields["activity-name"]
    name.tap()
    name.typeText("산책")
    app.buttons["activity-save"].tap()
    XCTAssertTrue(app.buttons["산책"].waitForExistence(timeout: 5))
    app.tabBars.buttons["오늘"].tap()
    XCTAssertTrue(app.staticTexts["산책"].exists)
  }

  @MainActor func testColorPreviewAndExplicitRecordActions() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    app.buttons["template-pages"].tap()
    app.buttons["icon-color-purple"].tap()
    let preview = XCTAttachment(screenshot: app.screenshot())
    preview.name = "아이콘 색상 미리보기"
    preview.lifetime = .keepAlways
    add(preview)
    app.buttons["activity-save"].tap()
    app.buttons["onboarding-finish"].tap()
    app.buttons["record-pages"].tap()
    app.textFields["entry-amount"].tap()
    app.textFields["entry-amount"].typeText("15")
    app.buttons["entry-save"].tap()
    app.tabBars.buttons["기록"].tap()
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "edit-entry-")).firstMatch
      .tap()
    XCTAssertTrue(app.navigationBars["기록 수정"].exists)
    for _ in 0..<5 where !app.buttons["기록 삭제"].isHittable { app.swipeUp() }
    app.buttons["기록 삭제"].tap()
    app.alerts.buttons["취소"].tap()
    XCTAssertTrue(app.buttons["entry-save"].exists)
    app.buttons["기록 삭제"].tap()
    app.alerts.buttons["삭제"].tap()
    XCTAssertTrue(app.staticTexts["아직 기록이 없어요"].waitForExistence(timeout: 5))
  }

  @MainActor func testActivityEditingAndDeletion() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    app.buttons["template-pages"].tap()
    XCTAssertTrue(app.textFields["threshold-1"].exists)
    XCTAssertTrue(app.textFields["threshold-2"].exists)
    for _ in 0..<3 where !app.textFields["threshold-3"].exists { app.swipeUp() }
    XCTAssertTrue(app.textFields["threshold-3"].exists)
    app.buttons["activity-save"].tap()
    app.buttons["onboarding-finish"].tap()
    app.buttons["최소 5쪽 달성"].tap()
    app.tabBars.buttons["설정"].tap()
    app.buttons["독서"].tap()
    XCTAssertFalse(app.textFields["activity-name"].isEnabled)
    XCTAssertFalse(app.buttons["activity-save"].exists)
    app.buttons["편집"].tap()
    XCTAssertTrue(app.textFields["activity-name"].isEnabled)
    for _ in 0..<8 where !app.buttons["활동 삭제"].isHittable { app.swipeUp() }
    app.buttons["활동 삭제"].tap()
    app.alerts.buttons["취소"].tap()
    XCTAssertTrue(app.buttons["activity-save"].exists)
    app.buttons["활동 삭제"].tap()
    app.alerts.buttons["삭제"].tap()
    XCTAssertFalse(app.buttons["독서"].exists)
    app.tabBars.buttons["오늘"].tap()
    XCTAssertTrue(app.staticTexts["오늘 0 XP"].exists)
  }

  @MainActor func testReadingOnboardingAndGrowth() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    XCTAssertTrue(app.buttons["template-pages"].waitForExistence(timeout: 10))
    app.buttons["template-pages"].tap()
    app.buttons["activity-save"].tap()
    app.buttons["onboarding-finish"].tap()
    XCTAssertTrue(app.buttons["record-pages"].waitForExistence(timeout: 5))
    app.buttons["record-pages"].tap()
    let amount = app.textFields["entry-amount"]
    XCTAssertTrue(amount.waitForExistence(timeout: 5))
    amount.tap()
    amount.typeText("15")
    app.buttons["entry-save"].tap()
    XCTAssertTrue(app.staticTexts["오늘 15쪽"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["오늘 15 XP"].exists)
    let todayShot = XCTAttachment(screenshot: app.screenshot())
    todayShot.name = "오늘 캐주얼 UI"
    todayShot.lifetime = .keepAlways
    add(todayShot)
    app.tabBars.buttons["성장"].tap()
    XCTAssertTrue(app.staticTexts["측정 가능한 성장"].exists)
    app.swipeUp()
    XCTAssertTrue(app.staticTexts["15쪽 쌓았어요"].waitForExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "성장 화면"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  @MainActor func testPersistentReadingAcrossRelaunch() {
    let app = XCUIApplication()
    app.launchArguments = ["--test-store", UUID().uuidString]
    app.launch()
    XCTAssertTrue(app.buttons["template-pages"].waitForExistence(timeout: 10))
    app.buttons["template-pages"].tap()
    app.buttons["activity-save"].tap()
    app.buttons["onboarding-finish"].tap()
    app.buttons["record-pages"].tap()
    let amount = app.textFields["entry-amount"]
    amount.tap()
    amount.typeText("12")
    app.buttons["entry-save"].tap()
    XCTAssertTrue(app.staticTexts["오늘 12쪽"].waitForExistence(timeout: 5))
    app.terminate()
    app.launch()
    XCTAssertTrue(app.staticTexts["오늘 12쪽"].waitForExistence(timeout: 10))
  }
  @MainActor func testCustomActivityAndQuickConfirmation() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    app.buttons["직접 만들기"].tap()
    let name = app.textFields["activity-name"]
    name.tap()
    name.typeText("스트레칭")
    app.buttons["activity-save"].tap()
    app.buttons["onboarding-finish"].tap()
    app.buttons["최소 1회 달성"].tap()
    XCTAssertTrue(app.staticTexts["최소 달성 확인 · 수치 미기록"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["오늘 10 XP"].exists)
    app.buttons["실행 취소"].tap()
    XCTAssertTrue(app.staticTexts["오늘 0 XP"].exists)
    XCTAssertTrue(app.buttons["최소 1회 달성"].exists)
  }
  @MainActor func testReadingRangeRefinesQuickEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    app.buttons["template-pages"].tap()
    app.buttons["activity-save"].tap()
    app.buttons["onboarding-finish"].tap()
    app.buttons["최소 5쪽 달성"].tap()
    app.buttons["record-pages"].tap()
    app.buttons["시작·마지막 페이지"].tap()
    let start = app.textFields["start-page"]
    start.tap()
    start.typeText("40")
    let end = app.textFields["last-page"]
    end.tap()
    end.typeText("55")
    app.buttons["entry-save"].tap()
    XCTAssertTrue(app.staticTexts["오늘 15쪽"].waitForExistence(timeout: 5))
    app.tabBars.buttons["기록"].tap()
    XCTAssertEqual(app.staticTexts.matching(identifier: "15쪽").count, 1)
  }
  @MainActor func testDarkLargeTextOnboarding() {
    let app = XCUIApplication()
    app.launchArguments = [
      "--uitesting", "--large-text-dark",
    ]
    app.launch()
    XCTAssertTrue(app.buttons["template-pages"].waitForExistence(timeout: 10))
    for _ in 0..<4 where !app.buttons["template-pages"].isHittable { app.swipeUp() }
    XCTAssertTrue(app.buttons["template-pages"].isHittable)
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "큰 글자 다크 온보딩"
    image.lifetime = .keepAlways
    add(image)
    app.buttons["template-pages"].tap()
    XCTAssertTrue(app.buttons["activity-save"].waitForExistence(timeout: 5))
    app.buttons["activity-save"].tap()
    for _ in 0..<5 where !app.buttons["onboarding-finish"].isHittable { app.swipeUp() }
    XCTAssertTrue(app.buttons["onboarding-finish"].isHittable)
  }

}
