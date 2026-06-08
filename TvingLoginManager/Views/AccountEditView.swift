import SwiftUI

struct AccountEditView: View {
    @EnvironmentObject var manager: AccountManager
    @FocusState private var focusedField: Field?
    @State private var showPassword = false

    private enum Field: Hashable {
        case title, username, password
    }

    var body: some View {
        Form {
            Section {
                TextField("Account Title", text: $manager.editTitle)
                    .focused($focusedField, equals: .title)
                TextField("TVING ID", text: $manager.editUsername)
                    .focused($focusedField, equals: .username)
                    .textContentType(.username)
                HStack {
                    if showPassword {
                        TextField("Password", text: $manager.editPassword)
                            .focused($focusedField, equals: .password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $manager.editPassword)
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
                Picker("Account Type", selection: $manager.editAccountType) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Plan", selection: $manager.editPlanType) {
                    ForEach(PlanType.allCases, id: \.self) { plan in
                        Text(plan.rawValue).tag(plan)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(manager.editingAccountId != nil ? "Edit Account" : "New Account")
            }

            Section {
                HStack {
                    Button("Cancel", role: .cancel) {
                        manager.cancelEditing()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Button(manager.editingAccountId != nil ? "Update" : "Save") {
                        manager.saveEdit()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(!manager.isEditFormValid)
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
                if manager.isEditFormValid { manager.saveEdit() }
            case nil: break
            }
        }
    }
}
