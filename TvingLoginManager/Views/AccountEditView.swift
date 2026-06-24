import SwiftUI

struct AccountEditView: View {
    @EnvironmentObject var store: AccountStore
    @FocusState private var focusedField: Field?
    @State private var showPassword = false

    private enum Field: Hashable {
        case title, username, password
    }

    var body: some View {
        Form {
            Section {
                TextField("Account Title", text: store.binding(\.editTitle, send: AccountAction.setEditTitle))
                    .accessibilityIdentifier("edit_title")
                    .focused($focusedField, equals: .title)
                TextField("TVING ID", text: store.binding(\.editUsername, send: AccountAction.setEditUsername))
                    .accessibilityIdentifier("edit_username")
                    .focused($focusedField, equals: .username)
                    .textContentType(.username)
                HStack {
                    if showPassword {
                        TextField("Password", text: store.binding(\.editPassword, send: AccountAction.setEditPassword))
                            .focused($focusedField, equals: .password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: store.binding(\.editPassword, send: AccountAction.setEditPassword))
                            .focused($focusedField, equals: .password)
                            .textContentType(.password)
                    }
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                Picker("Account Type", selection: store.binding(\.editAccountType, send: AccountAction.setEditAccountType)) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Plan", selection: store.binding(\.editPlanType, send: AccountAction.setEditPlanType)) {
                    ForEach(PlanType.allCases, id: \.self) { plan in
                        Text(plan.displayName).tag(plan)
                    }
                }
                .pickerStyle(.radioGroup)

                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: store.binding(\.editMemo, send: AccountAction.setEditMemo))
                        .accessibilityIdentifier("edit_memo")
                        .frame(height: 80)
                        .font(.body)
                    Text("\(store.state.editMemo.count)/250")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } header: {
                Text(store.state.editingAccountId != nil ? LocalizedStringKey("Edit Account") : LocalizedStringKey("New Account"))
            }

            Section {
                HStack {
                    Button("Cancel", role: .cancel) {
                        store.send(.cancelEditing)
                    }
                    .accessibilityIdentifier("edit_cancel")
                    .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Button(store.state.editingAccountId != nil ? LocalizedStringKey("Update") : LocalizedStringKey("Save")) {
                        store.send(.saveEdit)
                    }
                    .accessibilityIdentifier("edit_save")
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.state.isEditFormValid)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            focusedField = .title
        }
        .onSubmit {
            switch focusedField {
            case .title: focusedField = .username
            case .username: focusedField = .password
            case .password:
                if store.state.isEditFormValid { store.send(.saveEdit) }
            case nil: break
            }
        }
    }
}
