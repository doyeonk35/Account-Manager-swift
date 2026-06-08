import SwiftUI

struct AccountListView: View {
    @EnvironmentObject var manager: AccountManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("OTP Code:")
                TextField("Enter OTP", text: $manager.otpCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 4)

            if manager.accounts.isEmpty {
                ContentUnavailableView {
                    Label("No Accounts", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Add an account to get started.")
                } actions: {
                    Button("Add Account") { manager.startAdding() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(manager.accounts) { account in
                    accountRow(account)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: Binding(
                get: { manager.accountToDelete != nil },
                set: { if !$0 { manager.accountToDelete = nil } }
            ),
            presenting: manager.accountToDelete
        ) { account in
            Button("Delete \"\(account.title)\"", role: .destructive) {
                manager.deleteAccount(id: account.id)
                manager.accountToDelete = nil
            }
        } message: { account in
            Text("This will permanently delete the account and its stored password.")
        }
    }

    private func accountRow(_ account: AccountInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(account.title)
                        .font(.headline)
                    Text(account.lastUsedRelative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("ID: \(account.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Type: \(account.accountType.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    manager.startEditing(account: account)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    manager.accountToDelete = account
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)

                Button("Login") {
                    manager.startLogin(account: account)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(manager.isLoggingIn)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            manager.selectedAccountId == account.id
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
    }
}
