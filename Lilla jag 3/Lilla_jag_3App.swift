import SwiftUI

@main
struct Lilla_jag_3App: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Under UI-testning hoppar vi onboarding och startar direkt i RootContainer.
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    var body: some Scene {
        WindowGroup {
            if isUITesting {
                RootContainer()
            } else if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
    }
}
