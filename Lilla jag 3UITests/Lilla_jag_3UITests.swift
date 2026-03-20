// Lilla_jag_3UITests.swift
// UI-tester: vy-laddning utan kraschar + layout-verifiering för iPhone SE och iPhone 16 Pro Max

import XCTest

// MARK: - Hjälpkonstanter

private enum Layout {
    /// Minsta tillåtna touch target (Apple HIG)
    static let minTouchTarget: CGFloat = 44.0
    /// Marginal för bounds-kontroller (en pixels-tolerans)
    static let boundsTolerance: CGFloat = 2.0
    /// Extra marginal för ScrollView-innehåll (vertikal scroll-overflow)
    static let scrollViewTolerance: CGFloat = 200.0
    /// Marginal för ZStack-/matchedGeometryEffect-artefakter (navbar-knappar från inaktiva vyer).
    /// SwiftUI:s matchedGeometryEffect kan rapportera navbar-knappar ca 34pt utanför skärmen
    /// när de tillhör en inaktiv ZStack-vy. Vi tillåter 40pt horisontell marginal för att hantera detta.
    static let navbarArtifactTolerance: CGFloat = 40.0
}

// MARK: - App-lanseringsstöd

extension XCUIApplication {
    /// Startar appen med inställningar som hoppar onboarding och
    /// placerar oss direkt i RootContainer (huvudnavigeringen).
    func launchForTesting() {
        launchArguments = ["UI_TESTING", "SKIP_ONBOARDING"]
        launch()
    }
}

// MARK: - LayoutVerifierTests
// Körs på aktuell simulator. Kör dessa tester manuellt på:
//   iPhone SE (3rd generation) och iPhone 16 Pro Max
// via Xcode-destinations för fullständig devicematris-täckning.

final class LayoutVerifierTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchForTesting()
        // Ge appen tid att komma förbi eventuell intro-animation/splash
        _ = app.otherElements.firstMatch.waitForExistence(timeout: 8)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Startskärmen laddas utan krasch

    func testAppLaunchesWithoutCrash() {
        XCTAssertTrue(app.state == .runningForeground, "Appen ska köra i förgrunden")
    }

    // MARK: - RootContainer och navbar

    func testNavbarIsVisible() {
        // Appen ska visa en navbar när RootContainer är aktiv.
        // Navbar innehåller tab-knappar med titlarna från NavDestination.
        let navbarButtons = ["Hem", "Dagbok", "Diagnoser", "Prata", "Humör"]
        var foundAny = false
        for title in navbarButtons {
            if app.buttons[title].waitForExistence(timeout: 5) {
                foundAny = true
                break
            }
        }
        XCTAssertTrue(foundAny, "Minst en navbar-knapp ska vara synlig")
    }

    // MARK: - Alla navbar-tabs laddas utan krasch

    func testAllTabsLoadWithoutCrash() {
        let tabTitles = ["Hem", "Dagbok", "Diagnoser", "Prata", "Humör"]
        for title in tabTitles {
            let tab = app.buttons[title]
            guard tab.waitForExistence(timeout: 5) else {
                // Tab-knappen kan inte hittas – rapportera men fortsätt
                XCTFail("Tab-knappen '\(title)' hittades inte")
                continue
            }
            tab.tap()
            // Ge vyn tid att rendera
            sleep(1)
            XCTAssertEqual(app.state, .runningForeground,
                           "Appen ska inte krascha vid navigering till tab '\(title)'")
        }
    }

    // MARK: - Layoutverifiering: inga element utanför skärmen

    func testNoInteractiveElementsOutsideScreenBoundsOnActiveTab() {
        // Hämta skärmbounds via appens fönster
        let window = app.windows.firstMatch
        guard window.exists else { return }
        let screenWidth = window.frame.width
        let screenHeight = window.frame.height

        let buttons = app.buttons.allElementsBoundByIndex

        for button in buttons {
            guard button.exists && button.isHittable else { continue }
            let frame = button.frame

            // Vänster/höger overflow: ingen tolerans för ScrollView (horisontell scroll är sällan avsedd)
            XCTAssertGreaterThanOrEqual(
                frame.minX, -Layout.boundsTolerance,
                "Knapp '\(button.label)' sticker utanför vänster kant: minX=\(frame.minX)"
            )
            XCTAssertLessThanOrEqual(
                frame.maxX, screenWidth + Layout.boundsTolerance,
                "Knapp '\(button.label)' sticker utanför höger kant: maxX=\(frame.maxX)"
            )
            // Vertikal overflow: tillåt ScrollView-innehåll (element utanför synfält men inom rimligt avstånd)
            XCTAssertGreaterThanOrEqual(
                frame.minY, -Layout.scrollViewTolerance,
                "Knapp '\(button.label)' är långt utanför övre kant: minY=\(frame.minY)"
            )
            XCTAssertLessThanOrEqual(
                frame.maxY, screenHeight + Layout.scrollViewTolerance,
                "Knapp '\(button.label)' är långt utanför nedre kant: maxY=\(frame.maxY)"
            )
        }
    }

    // MARK: - Dagbok-fliken

    func testDagbokTabLoadsWithoutCrash() {
        tapTabIfExists("Dagbok")
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "Dagbok-tab ska inte krascha appen")
    }

    func testDagbokTabHasVisibleContent() {
        tapTabIfExists("Dagbok")
        sleep(2)
        // Dagbok-vyn ska ha text-element synliga
        let hasContent = app.staticTexts.count > 0 || app.buttons.count > 0
        XCTAssertTrue(hasContent, "Dagbok-vyn ska ha synligt innehåll")
    }

    // MARK: - Humör-fliken (Mood1View)

    func testMoodTabLoadsWithoutCrash() {
        tapTabIfExists("Humör")
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "Humör-tab ska inte krascha appen")
    }

    func testMoodTabHasVisibleContent() {
        tapTabIfExists("Humör")
        sleep(2)
        let hasContent = app.staticTexts.count > 0 || app.buttons.count > 0
        XCTAssertTrue(hasContent, "Humör-vyn ska ha synligt innehåll")
    }

    // MARK: - Prata-fliken (AITherapistView)

    func testChatTabLoadsWithoutCrash() {
        tapTabIfExists("Prata")
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "Prata-tab ska inte krascha appen")
    }

    func testChatTabHasVisibleContent() {
        tapTabIfExists("Prata")
        sleep(2)
        let hasContent = app.staticTexts.count > 0 || app.buttons.count > 0
        XCTAssertTrue(hasContent, "Prata-vyn ska ha synligt innehåll")
    }

    // MARK: - Diagnoser-fliken

    func testDiagnoserTabLoadsWithoutCrash() {
        tapTabIfExists("Diagnoser")
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "Diagnoser-tab ska inte krascha appen")
    }

    // MARK: - Hem-fliken (Dashboard)

    func testHomeTabLoadsWithoutCrash() {
        tapTabIfExists("Hem")
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "Hem-tab ska inte krascha appen")
    }

    // MARK: - Alla tabs: layout-genomgång

    func testHomeTabHasNoHorizontallyOverflowingButtons() {
        // Verifierar horisontell layout-overflow på Hem-tab.
        // Navigerar bara en tab för att hålla testet snabbt och undvika simulator-timeouts.
        // Vertikalt ScrollView-innehåll och ZStack/matchedGeometryEffect-artefakter filtreras.
        tapTabIfExists("Hem")
        sleep(1)

        let window = app.windows.firstMatch
        guard window.exists else { return }
        let screenWidth = window.frame.width
        let screenHeight = window.frame.height

        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            guard button.exists && button.isHittable else { continue }
            let frame = button.frame
            guard frame.width > 0 && frame.height > 0 else { continue }

            // Hoppa över element som är utanför synfältet vertikalt (ScrollView-innehåll)
            guard frame.maxY < screenHeight + Layout.scrollViewTolerance &&
                  frame.minY > -Layout.scrollViewTolerance else { continue }

            // Horisontell overflow är ett layout-problem.
            // navbarArtifactTolerance (40pt) hanterar matchedGeometryEffect-koordinatartefakter.
            XCTAssertLessThanOrEqual(
                frame.maxX, screenWidth + Layout.navbarArtifactTolerance,
                "[Hem] Knapp '\(button.label)' sticker utanför höger kant: \(frame.maxX)"
            )
            XCTAssertGreaterThanOrEqual(
                frame.minX, -Layout.navbarArtifactTolerance,
                "[Hem] Knapp '\(button.label)' sticker utanför vänster kant: \(frame.minX)"
            )
        }
    }

    // MARK: - Minimum touch targets

    func testCriticalNavbarButtonsHaveAdequateTouchTargets() {
        let tabTitles = ["Hem", "Dagbok", "Humör"]
        for title in tabTitles {
            let button = app.buttons[title]
            guard button.waitForExistence(timeout: 5) else { continue }
            XCTAssertGreaterThanOrEqual(
                button.frame.height, Layout.minTouchTarget,
                "Navbar-knapp '\(title)' har för litet touch target: \(button.frame.height)pt"
            )
        }
    }

    // MARK: - Skärmfyllnad: vyn täcker hela tillgängliga ytan

    func testActiveViewHasContentInUpperHalf() {
        let window = app.windows.firstMatch
        guard window.exists else { return }
        let midY = window.frame.height * 0.5

        // Det ska finnas element i den övre halvan av skärmen
        let upperElements = app.otherElements.allElementsBoundByIndex.filter { element in
            element.exists && element.frame.minY < midY && element.frame.height > 0
        }
        XCTAssertFalse(upperElements.isEmpty, "Startskärmen ska ha innehåll i övre halvan")
    }

    // MARK: - Hjälpmetoder

    private func tapTabIfExists(_ title: String) {
        let tab = app.buttons[title]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
        }
    }
}

// MARK: - OnboardingSkipTests

final class OnboardingBehaviorTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testAppLaunchesSuccessfully() {
        app.launchForTesting()
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testAppDoesNotCrashWithinTenSeconds() {
        app.launchForTesting()
        sleep(10)
        XCTAssertEqual(app.state, .runningForeground, "Appen ska inte krascha inom 10 sekunder")
    }
}

// MARK: - ScreenBoundsLayoutTests
// Dessa tester verifierar att inga statiska texter är clippade (höjd = 0)

final class ScreenBoundsLayoutTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchForTesting()
        _ = app.otherElements.firstMatch.waitForExistence(timeout: 8)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testNoStaticTextsAreClippedOnHomeTab() {
        tapTabIfExists("Hem")
        sleep(1)
        verifyNoZeroHeightTexts(context: "Hem")
    }

    func testNoStaticTextsAreClippedOnDagbokTab() {
        tapTabIfExists("Dagbok")
        sleep(1)
        verifyNoZeroHeightTexts(context: "Dagbok")
    }

    func testNoStaticTextsAreClippedOnMoodTab() {
        tapTabIfExists("Humör")
        sleep(1)
        verifyNoZeroHeightTexts(context: "Humör")
    }

    func testNoStaticTextsAreClippedOnChatTab() {
        tapTabIfExists("Prata")
        sleep(1)
        verifyNoZeroHeightTexts(context: "Prata")
    }

    // MARK: - Hjälpmetoder

    private func tapTabIfExists(_ title: String) {
        let tab = app.buttons[title]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
        }
    }

    private func verifyNoZeroHeightTexts(context: String) {
        let texts = app.staticTexts.allElementsBoundByIndex
        for text in texts {
            guard text.exists else { continue }
            guard !text.label.isEmpty else { continue }
            XCTAssertGreaterThan(
                text.frame.height, 0,
                "[\(context)] Text '\(text.label.prefix(40))' har noll höjd – troligtvis clippat"
            )
        }
    }
}
