import SwiftUI
import Sparkle

struct ContentView: View {
    @EnvironmentObject var manager: AccountManager
    let updater: SPUUpdater
    @State private var selectedTab: SidebarTab = .accounts
    @State private var selectedSettingsCategory: SettingsCategory?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $selectedTab) { tab in
                Label(LocalizedStringKey(tab.rawValue), systemImage: tab.icon)
                    .tag(tab)
                    .accessibilityIdentifier("sidebar_\(tab.rawValue.lowercased())")
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } content: {
            VStack(spacing: 0) {
                switch selectedTab {
                case .accounts:
                    AccountListView()
                case .settings:
                    SettingsView(selectedCategory: $selectedSettingsCategory)
                }

                Divider()

                HStack {
                    Text(manager.loginStatus)
                        .font(.footnote)
                        .foregroundStyle(manager.isLoggingIn ? .orange : .secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 400)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if selectedTab == .accounts {
                        Button {
                            manager.startAdding()
                        } label: {
                            Label("Add Account", systemImage: "plus")
                        }
                        .accessibilityIdentifier("add_account")
                        .keyboardShortcut("n", modifiers: .command)
                        .disabled(manager.isEditing)
                    }
                }
            }
        } detail: {
            if selectedTab == .accounts && manager.isEditing {
                AccountEditView()
                    .frame(minWidth: 300)
            } else if selectedTab == .settings, let category = selectedSettingsCategory {
                switch category {
                case .environment:
                    SettingsEnvironmentView()
                case .general:
                    SettingsGeneralView(updater: updater)
                }
            }
        }
        .onChange(of: selectedTab) {
            manager.cancelEditing()
            selectedSettingsCategory = nil
        }
        .sheet(isPresented: $manager.showLoginWebView) {
            if let account = manager.loginAccount {
                LoginWebView(account: account, otpCode: manager.otpCode)
                    .environmentObject(manager)
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
