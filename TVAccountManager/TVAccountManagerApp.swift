import SwiftUI
import Sparkle

// 진입점은 CLI/main.swift — `@main` 대신 거기서 GUI/CLI를 분기한다.
struct TVAccountManagerApp: App {
    @StateObject private var accountStore: AccountStore
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var router = AppRouter()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    init() {
        let repository = AccountRepositoryImpl()
        let useCase = AccountUseCase(repository: repository)
        let accountStore = AccountStore(
            initialState: AccountState(),
            reducer: AccountEnvironment.reducer(useCase: useCase)
        )
        // 창 없이 메뉴바로만 떠 있어도 계정 목록이 있어야 한다
        accountStore.send(.load)
        _accountStore = StateObject(wrappedValue: accountStore)
        _settingsStore = StateObject(wrappedValue: SettingsStore(
            initialState: SettingsState(),
            reducer: SettingsEnvironment.reducer
        ))
    }

    var body: some Scene {
        // 창이 여러 개면 router를 같이 써서 탭 이동이 함께 움직인다 — 메인 창은 하나만.
        Window(Text(verbatim: Self.appName), id: MainWindow.id) {
            ContentView(updater: updaterController.updater)
                .environmentObject(accountStore)
                .environmentObject(settingsStore)
                .environmentObject(router)
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
            CommandGroup(replacing: .appSettings) {
                OpenSettingsButton(accountStore: accountStore, router: router)
            }
        }

        Window("Usage Guide", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarView()
                .environmentObject(accountStore)
                .environmentObject(settingsStore)
                .environmentObject(router)
        } label: {
            Image(systemName: "tv")
        }
        .menuBarExtraStyle(.window)
    }

    private static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "TVAccountManager"
    }
}

enum MainWindow {
    static let id = "main"
}

/// ⌘, — 설정은 별도 창이 아니라 메인 창의 사이드바 탭이다.
private struct OpenSettingsButton: View {
    let accountStore: AccountStore
    let router: AppRouter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            openWindow(id: MainWindow.id)
            NSApp.activate()
            // 이미 설정 탭이면 그대로 둔다 (편집 중인 URL 초안 보존).
            // 계정 편집 중이면 입력을 버리지 않도록 창만 앞으로 가져온다.
            guard router.tab != .settings, !accountStore.state.isEditing else { return }
            router.navigateTo(tab: .settings)
            router.settingsCategory = .general
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
