import SwiftUI
import Sparkle

@main
struct TvingLoginManagerApp: App {
    @StateObject private var accountManager = AccountManager()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountManager)
                .frame(minWidth: 900, minHeight: 500)
        }
        .defaultSize(width: 1100, height: 650)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(
                    viewModel: CheckForUpdatesViewModel(
                        updater: updaterController.updater
                    )
                )
            }
        }

        Window("Usage Guide", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
