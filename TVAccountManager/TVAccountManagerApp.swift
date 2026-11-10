import SwiftUI
import Sparkle

// 진입점은 CLI/main.swift — `@main` 대신 거기서 GUI/CLI를 분기한다.
struct TVAccountManagerApp: App {
    @StateObject private var accountStore: AccountStore
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var router = AppRouter()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
        SettingsState.migrateStoredURLs()
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

/// 로그인 시 자동 실행이면 메인 창 없이 메뉴바로만 시작한다.
/// 실행 Apple Event는 applicationDidFinishLaunching 안에서만 읽을 수 있다 (willFinish 시점엔 아직 없다).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var launchedAsLoginItem = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        guard event?.eventID == AEEventID(kAEOpenApplication),
              event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        else { return }
        Self.launchedAsLoginItem = true
        // 메인 창이 이미 떠 있을 수도, 아직일 수도 있다 — 떠 있는 창은 이 알림으로 닫는다
        NotificationCenter.default.post(name: .launchedAsLoginItem, object: nil)
    }
}

extension Notification.Name {
    static let launchedAsLoginItem = Notification.Name("launchedAsLoginItem")
}

/// 메인 창 배경에 깔아 두는 뷰. 로그인 시 자동 실행이면 자기가 속한 창을 닫는다.
/// (dismissWindow는 첫 onAppear 시점엔 창이 아직 등록되지 않아 무시될 수 있다)
struct LoginLaunchWindowCloser: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { CloserView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class CloserView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            closeIfLaunchedAtLogin()
            // 셀렉터 방식 관찰자는 뷰가 해제될 때 자동으로 풀린다
            NotificationCenter.default.addObserver(self, selector: #selector(closeIfLaunchedAtLogin),
                                                   name: .launchedAsLoginItem, object: nil)
        }

        @objc private func closeIfLaunchedAtLogin() {
            // 메뉴바를 꺼 뒀으면 창을 닫으면 앱에 접근할 길이 없다
            guard AppDelegate.launchedAsLoginItem,
                  UserDefaults.standard.object(forKey: "showMenuBarExtra") as? Bool ?? true
            else { return }
            AppDelegate.launchedAsLoginItem = false
            DispatchQueue.main.async { [weak self] in self?.window?.close() }
        }
    }
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
