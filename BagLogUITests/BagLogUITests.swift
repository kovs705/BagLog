import XCTest

final class BagLogUITests: XCTestCase {
    func testCreateTwoItemsAndPublishWithoutLosingKeyboardFocus() {
        let app = XCUIApplication()
        launchCleanEditor(app)

        let title = app.textFields["kit-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("Keyboard kit\n")

        let composer = app.textFields["item-composer"]
        Thread.sleep(forTimeInterval: 0.3)
        composer.typeText("Camera\n")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(staticText("Camera", in: app).waitForExistence(timeout: 2))

        composer.typeText("Water\n")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(staticText("Water", in: app).waitForExistence(timeout: 2))

        app.buttons["publish-kit"].tap()
        app.buttons["Publish on This Device"].tap()

        XCTAssertTrue(app.navigationBars["Keyboard kit"].waitForExistence(timeout: 5))
        XCTAssertTrue(staticText("Camera", in: app).exists)
        XCTAssertTrue(staticText("Water", in: app).exists)
    }

    func testSavedDraftClosesAndReopensInTheEditor() {
        let app = XCUIApplication()
        launchCleanEditor(app)

        let title = app.textFields["kit-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("Reopen me\n")

        let composer = app.textFields["item-composer"]
        Thread.sleep(forTimeInterval: 0.3)
        composer.typeText("Flashlight\n")
        XCTAssertTrue(staticText("Flashlight", in: app).waitForExistence(timeout: 2))

        app.buttons["close-kit-editor"].tap()
        XCTAssertTrue(app.buttons["create-kit-button"].waitForExistence(timeout: 3))
        app.buttons["My Kits"].tap()

        let draft = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "edit-draft-")
        ).firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 3))
        draft.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()

        let reopenedTitle = app.textFields["kit-title"]
        XCTAssertTrue(reopenedTitle.waitForExistence(timeout: 3))
        XCTAssertEqual(reopenedTitle.value as? String, "Reopen me")
        XCTAssertTrue(staticText("Flashlight", in: app).exists)
    }

    func testItemDetailsOpenInASeparateSheet() {
        let app = XCUIApplication()
        launchCleanEditor(app)

        let title = app.textFields["kit-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("Sheet kit\n")

        let composer = app.textFields["item-composer"]
        Thread.sleep(forTimeInterval: 0.3)
        composer.typeText("Passport wallet\n")
        XCTAssertTrue(staticText("Passport wallet", in: app).waitForExistence(timeout: 2))

        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "edit-item-")
        ).firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Item details"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["finish-item-editor"].exists)

        app.buttons["finish-item-editor"].tap()
        XCTAssertTrue(app.textFields["item-composer"].waitForExistence(timeout: 2))
    }

    func testTopicPickerSelectsTopicFromSeparateSheet() {
        let app = XCUIApplication()
        launchCleanEditor(app)

        let topicButton = app.buttons["choose-kit-topic"]
        XCTAssertTrue(topicButton.waitForExistence(timeout: 3))
        topicButton.tap()

        XCTAssertTrue(app.navigationBars["Choose a topic"].waitForExistence(timeout: 2))

        let search = app.textFields["topic-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 2))
        search.tap()
        search.typeText("cam")
        XCTAssertTrue(app.buttons["topic-option-camera"].waitForExistence(timeout: 2))
        XCTAssertTrue(staticText("1 topic", in: app).exists)
        XCTAssertFalse(app.buttons["topic-option-travel"].exists)

        app.buttons["Clear search"].tap()

        let travelTopic = app.buttons["topic-option-travel"]
        XCTAssertTrue(travelTopic.waitForExistence(timeout: 2))
        travelTopic.tap()

        XCTAssertTrue(topicButton.waitForExistence(timeout: 2))
        XCTAssertEqual(topicButton.label, "Topic, Travel")
    }

    private func launchCleanEditor(_ app: XCUIApplication) {
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["create-kit-button"].tap()

        let displayName = app.textFields["profile-display-name"]
        XCTAssertTrue(displayName.waitForExistence(timeout: 3))
        displayName.typeText("UI Tester\n")

        let handle = app.textFields["profile-handle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 2))
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 0.4)
        handle.typeText("ui-tester\n")
    }

    private func staticText(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}
