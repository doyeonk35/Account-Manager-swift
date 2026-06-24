import SwiftUI
import Sparkle

struct ContentView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var router: AppRouter
    let updater: SPUUpdater
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $router.tab) { tab in
                Label(LocalizedStringKey(tab.rawValue), systemImage: tab.icon)
                    .tag(tab)
                    .accessibilityIdentifier("sidebar_\(tab.rawValue.lowercased())")
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } content: {
            VStack(spacing: 0) {
                switch router.tab {
                case .accounts:
                    AccountListView()
                case .settings:
                    SettingsView(selectedCategory: $router.settingsCategory)
                }

                Divider()

                HStack {
                    Text(accountStore.state.loginStatus)
                        .font(.footnote)
                        .foregroundStyle(accountStore.state.isLoggingIn ? .orange : .secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 400)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if router.tab == .accounts {
                        Button {
                            accountStore.send(.startAdding)
                        } label: {
                            Label("Add Account", systemImage: "plus")
                        }
                        .accessibilityIdentifier("add_account")
                        .keyboardShortcut("n", modifiers: .command)
                        .disabled(accountStore.state.isEditing)
                    }
                }
            }
        } detail: {
            if router.tab == .accounts && accountStore.state.isEditing {
                AccountEditView()
                    .frame(minWidth: 300)
            } else if router.tab == .settings, let category = router.settingsCategory {
                switch category {
                case .environment:
                    SettingsEnvironmentView()
                case .general:
                    SettingsGeneralView(updater: updater)
                }
            }
        }
        .onChange(of: router.tab) {
            accountStore.send(.cancelEditing)
            router.settingsCategory = nil
        }
        .sheet(isPresented: Binding(
            get: { accountStore.state.showLoginWebView },
            set: { if !$0 { accountStore.send(.dismissLoginWebView) } }
        )) {
            if let account = accountStore.state.loginAccount {
                LoginWebView(
                    account: account,
                    otpCode: accountStore.state.otpCode,
                    loginURL: SettingsState.loginURL(for: account.accountType)
                )
                .environmentObject(accountStore)
                .frame(minWidth: 900, minHeight: 700)
            }
        }
        .onAppear {
            if !hasSeenOnboarding {
                openWindow(id: "onboarding")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
            openWindow(id: "onboarding")
        }
    }
}

extension Notification.Name {
    static let showOnboarding = Notification.Name("showOnboarding")
}
