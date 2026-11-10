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

            Section("Profiles") {
                if account.profiles.isEmpty {
                    Text("Profiles are filled in automatically when you log in.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(account.profiles) { profile in
                        HStack {
                            ProfileLabel(profile: profile)
                            Spacer()
                            if profile.isLocked {
                                if account.profilePins[profile.profileNo] != nil {
                                    Label("PIN saved", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Label("PIN needed", systemImage: "exclamationmark.circle")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
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
                    .help(Text("Edit account (⌘↩)"))

                    Button("Login") {
                        store.send(.startLogin(account))
                    }
                    .disabled(store.state.isLoggingIn)
                    .help(Text("Log the TV in with this account using the OTP code"))

                    Spacer()

                    Button(role: .destructive) {
                        store.send(.confirmDelete(account))
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .help(Text("Delete account"))
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

/// 프로필 이름 · 대표 표시 · 자물쇠 · 연령 배지. 상세·편집 화면 공용.
struct ProfileLabel: View {
    let profile: ProfileInfo

    var body: some View {
        HStack(spacing: 6) {
            Text(profile.name)
            if profile.isMain {
                Text("Main")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if profile.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Locked"))
                    .help(Text("Locked profile — needs a PIN"))
            }
            Text(profile.gradeDisplayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.gray.opacity(0.15))
                .clipShape(Capsule())
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
