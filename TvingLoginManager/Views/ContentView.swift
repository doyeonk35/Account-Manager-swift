import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: AccountManager

    var body: some View {
        VStack(spacing: 0) {
            if manager.isEditing {
                AccountEditView()
            } else {
                AccountListView()
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
            ToolbarItem(placement: .navigation) {
                Text("TVING Account Manager")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    manager.startAdding()
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(manager.isEditing)
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
