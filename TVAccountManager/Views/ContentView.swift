import SwiftUI
import Sparkle

struct ContentView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var router: AppRouter
    let updater: SPUUpdater
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.openWindow) private var openWindow

    @State private var showUnsavedAlert = false
    @State private var pendingTab: SidebarTab?
    @State private var pendingCategory: SettingsCategory?

    private var isOnEnvironmentSettings: Bool {
        router.tab == .settings && router.settingsCategory == .environment
    }

    private var guardedTabBinding: Binding<SidebarTab> {
        Binding(
            get: { router.tab },
            set: { newTab in
                guard newTab != router.tab else { return }
                if isOnEnvironmentSettings && settingsStore.state.hasUnsavedChanges {
                    pendingTab = newTab
                    pendingCategory = nil
                    showUnsavedAlert = true
                } else {
                    accountStore.send(.cancelEditing)
                    router.navigateTo(tab: newTab)
                }
            }
        )
    }

    private var guardedCategoryBinding: Binding<SettingsCategory?> {
        Binding(
            get: { router.settingsCategory },
            set: { newCategory in
                guard newCategory != router.settingsCategory else { return }
                if isOnEnvironmentSettings && settingsStore.state.hasUnsavedChanges {
                    pendingTab = nil
                    pendingCategory = newCategory
                    showUnsavedAlert = true
                } else {
                    router.settingsCategory = newCategory
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: guardedTabBinding) { tab in
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
                    SettingsView(selectedCategory: guardedCategoryBinding)
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
            } else if router.tab == .accounts, let account = accountStore.state.selectedAccount {
                AccountDetailView(account: account)
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
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Save", role: .none) {
                settingsStore.send(.saveChanges)
                applyPendingNavigation()
            }
            Button("Discard", role: .destructive) {
                settingsStore.send(.discardChanges)
                applyPendingNavigation()
            }
            Button("Cancel", role: .cancel) {
                pendingTab = nil
                pendingCategory = nil
            }
        } message: {
            Text("You have unsaved URL changes. Would you like to save them before leaving?")
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

    private func applyPendingNavigation() {
        if let tab = pendingTab {
            accountStore.send(.cancelEditing)
            router.navigateTo(tab: tab)
        } else if let category = pendingCategory {
            router.settingsCategory = category
        }
        pendingTab = nil
        pendingCategory = nil
    }
}

extension Notification.Name {
    static let showOnboarding = Notification.Name("showOnboarding")
}
