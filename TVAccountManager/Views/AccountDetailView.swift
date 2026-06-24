import SwiftUI

struct AccountDetailView: View {
    let account: AccountInfo
    @EnvironmentObject var store: AccountStore

    var body: some View {
        Form {
            Section {
                DetailRow(label: String(localized: "Account Title"), value: account.title)
                DetailRow(label: String(localized: "TVING ID"), value: account.username)
                DetailRow(label: String(localized: "Account Type"), value: account.accountType.rawValue)
                DetailRow(label: String(localized: "Plan"), value: account.planType.displayName)
            }

            if !account.memo.isEmpty {
                Section(String(localized: "Memo")) {
                    Text(account.memo)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Section {
                DetailRow(label: String(localized: "Date Added"), value: account.createdAt.formatted(date: .abbreviated, time: .shortened))
                DetailRow(label: String(localized: "Last Used"), value: account.lastUsed.formatted(date: .abbreviated, time: .shortened))
                if account.isPinned {
                    DetailRow(label: String(localized: "Pin to Top"), value: "★")
                }
            }

            Section {
                HStack {
                    Button("Edit") {
                        store.send(.startEditing(account))
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)

                    Button("Login") {
                        store.send(.startLogin(account))
                    }
                    .disabled(store.state.isLoggingIn)

                    Spacer()

                    Button(role: .destructive) {
                        store.send(.confirmDelete(account))
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Delete Account",
            isPresented: Binding(
                get: { store.state.accountToDelete != nil },
                set: { if !$0 { store.send(.cancelDelete) } }
            ),
            presenting: store.state.accountToDelete
        ) { target in
            Button("Delete \"\(target.title)\"", role: .destructive) {
                store.send(.delete(target.id))
            }
        } message: { _ in
            Text("This will permanently delete the account and its stored password.")
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
