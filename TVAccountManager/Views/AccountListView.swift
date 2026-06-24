import SwiftUI

struct AccountListView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupBox {
                HStack(spacing: 12) {
                    Label("OTP Code", systemImage: "lock.shield")
                        .foregroundStyle(.primary)
                        .font(.body.bold())
                    TextField("Enter 6-digit code", text: store.binding(\.otpCode, send: AccountAction.setOtpCode))
                        .accessibilityIdentifier("otp_field")
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .font(.system(.title3, design: .monospaced).bold())
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HStack(spacing: 0) {
                ForEach(AccountFilterTab.allCases, id: \.self) { tab in
                    Button {
                        store.send(.setFilterTab(tab))
                    } label: {
                        Text(tab.displayName)
                            .font(.subheadline)
                            .fontWeight(store.state.filterTab == tab ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(store.state.filterTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom)

            HStack(spacing: 8) {
                Picker("Sort", selection: store.binding(\.sortField, send: AccountAction.setSortField)) {
                    ForEach(AccountSortField.allCases, id: \.self) { field in
                        Text(field.displayName)
                            .tag(field)
                            .padding()
                    }
                }
                .pickerStyle(.menu)

                Button {
                    store.send(.toggleSortDirection)
                } label: {
                    Image(systemName: store.state.sortAscending ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.black)
                }
                .buttonStyle(.borderless)
                .help(store.state.sortAscending ? String(localized: "Ascending") : String(localized: "Descending"))

                Spacer()
            }
            .padding(.horizontal, 12)

            if store.state.accounts.isEmpty {
                ContentUnavailableView {
                    Label("No Accounts", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Add an account to get started.")
                } actions: {
                    Button("Add Account") { store.send(.startAdding) }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(store.state.sortedAccounts) { account in
                    accountRow(account)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: Binding(
                get: { store.state.accountToDelete != nil },
                set: { if !$0 { store.send(.cancelDelete) } }
            ),
            presenting: store.state.accountToDelete
        ) { account in
            Button("Delete \"\(account.title)\"", role: .destructive) {
                store.send(.delete(account.id))
            }
        } message: { account in
            Text("This will permanently delete the account and its stored password.")
        }
    }

    private func accountRow(_ account: AccountInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    if account.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text(account.title)
                        .font(.headline)
                    Text(account.lastUsedRelative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("ID: \(account.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(account.accountType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(account.planType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    store.send(.startEditing(account))
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("edit_\(account.title)")
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    store.send(.confirmDelete(account))
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("delete_\(account.title)")
                .buttonStyle(.borderless)

                Button("Login") {
                    store.send(.startLogin(account))
                }
                .accessibilityIdentifier("login_\(account.title)")
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(store.state.isLoggingIn)
            }
        }
        .accessibilityIdentifier("account_row_\(account.title)")
        .padding(.vertical, 4)
        .listRowBackground(
            store.state.selectedAccountId == account.id
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
    }
}
