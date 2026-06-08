import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: AccountManager

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $manager.selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            VStack(spacing: 0) {
                switch manager.selectedTab {
                case .accounts:
                    if manager.isEditing {
                        AccountEditView()
                    } else {
                        AccountListView()
                    }
                case .settings:
                    SettingsView()
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if manager.selectedTab == .accounts {
                        Button {
                            manager.startAdding()
                        } label: {
                            Label("Add Account", systemImage: "plus")
                        }
                        .keyboardShortcut("n", modifiers: .command)
                        .disabled(manager.isEditing)
                    }
                }
            }
        }
        .sheet(isPresented: $manager.showLoginWebView) {
            if let account = manager.loginAccount {
                LoginWebView(account: account, otpCode: manager.otpCode)
                    .environmentObject(manager)
                    .frame(minWidth: 900, minHeight: 700)
            }
        }
    }
}
