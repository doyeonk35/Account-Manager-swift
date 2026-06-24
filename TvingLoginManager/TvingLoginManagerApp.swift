import SwiftUI
import Sparkle

@main
struct TvingLoginManagerApp: App {
    @StateObject private var accountStore: AccountStore
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var router = AppRouter()

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    init() {
        let repository = AccountRepositoryImpl()
        let useCase = AccountUseCase(repository: repository)
        _accountStore = StateObject(wrappedValue: AccountStore(
            initialState: AccountState(),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        ))
        _settingsStore = StateObject(wrappedValue: SettingsStore(
            initialState: SettingsState(),
            reducer: SettingsEnvironment.reducer
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(updater: updaterController.updater)
                .environmentObject(accountStore)
                .environmentObject(settingsStore)
                .environmentObject(router)
                .frame(minWidth: 900, minHeight: 500)
                .onAppear {
                    accountStore.send(.load)
                }
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
