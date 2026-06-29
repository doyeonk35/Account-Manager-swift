import SwiftUI
import Sparkle

struct SettingsView: View {
    @Binding var selectedCategory: SettingsCategory?

    var body: some View {
        List(SettingsCategory.allCases, selection: $selectedCategory) { category in
            Label(LocalizedStringKey(category.rawValue), systemImage: category.icon)
                .tag(category)
                .accessibilityIdentifier("settings_\(category.rawValue.lowercased())")
                .padding(.vertical, 6)
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Environment Settings

struct SettingsEnvironmentView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                TextField("QC Login URL", text: store.binding(\.draftQcLoginURL, send: SettingsAction.setDraftQcLoginURL))
                    .accessibilityIdentifier("settings_qc_url")
                    .textFieldStyle(.roundedBorder)
                Text("Default: \(SettingsState.defaultQcURL)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("QC Environment")
            }

            Section {
                TextField("QA Login URL", text: store.binding(\.draftQaLoginURL, send: SettingsAction.setDraftQaLoginURL))
                    .accessibilityIdentifier("settings_qa_url")
                    .textFieldStyle(.roundedBorder)
                Text("Default: \(SettingsState.defaultQaURL)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("QA Environment")
            }

            Section {
                Button {
                    store.send(.useProductionURL)
                } label: {
                    HStack {
                        Label("Use Production URL", systemImage: "globe")
                        Spacer()
                        if store.state.isUsingProdURL {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .disabled(store.state.isUsingProdURL)
            } header: {
                Text("Quick Switch")
            } footer: {
                Text("Switches QC login URL to production (user.tving.com). Use 'Reset to Defaults' to restore.")
            }

            Section {
                HStack {
                    Button("Reset to Defaults") {
                        store.send(.resetToDefaults)
                    }
                    .accessibilityIdentifier("settings_reset")
                    .controlSize(.small)

                    Spacer()

                    Button("Save") {
                        store.send(.saveChanges)
                    }
                    .accessibilityIdentifier("settings_save")
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.state.hasUnsavedChanges)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Environment")
        .onAppear {
            store.send(.beginEditing)
        }
    }
}

// MARK: - General Settings

struct SettingsGeneralView: View {
    let updater: SPUUpdater
    @EnvironmentObject var accountStore: AccountStore

    private var importAlertTitle: LocalizedStringKey {
        guard let result = accountStore.state.importResult else { return "" }
        switch result {
        case .success: return "Import Complete"
        case .fileNotFound: return "File Not Found"
        case .parseError: return "Import Failed"
        }
    }

    private var importAlertMessage: LocalizedStringKey {
        guard let result = accountStore.state.importResult else { return "" }
        switch result {
        case .success(let imported, let skipped):
            if imported > 0 && skipped > 0 {
                return "\(imported) accounts imported, \(skipped) skipped (already exist)."
            } else if imported > 0 {
                return "\(imported) accounts imported."
            } else {
                return "All accounts already exist. Nothing to import."
            }
        case .fileNotFound:
            return "Place presets.json in ~/Library/Application Support/tving-login-manager/"
        case .parseError(let message):
            return "Failed to parse presets.json: \(message)"
        }
    }

    var body: some View {
        Form {
            Section {
                Button {
                    let dir = PresetAccount.presetsDirectory
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    PresetAccount.generateExampleFileIfNeeded()
                    NSWorkspace.shared.open(dir)
                } label: {
                    Label("Open Import Folder", systemImage: "folder")
                }
                .accessibilityIdentifier("settings_open_presets_folder")

                Button {
                    accountStore.send(.importPresets)
                } label: {
                    Label("Import Accounts from File", systemImage: "tray.and.arrow.down")
                }
                .accessibilityIdentifier("settings_import_presets")
            } header: {
                Text("Data")
            } footer: {
                Text("Open the folder to find presets.example.json with the format. Rename it to presets.json and fill in your accounts.")
            }

            Section {
                Button {
                    NotificationCenter.default.post(name: .showOnboarding, object: nil)
                } label: {
                    Label("View Usage Guide", systemImage: "questionmark.circle")
                }
                .accessibilityIdentifier("settings_show_guide")
            } header: {
                Text("Help")
            }

            Section {
                LabeledContent("Version") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                }
            } header: {
                Text("App Info")
            }

            Section {
                CheckForUpdatesView(
                    viewModel: CheckForUpdatesViewModel(updater: updater)
                )
            } header: {
                Text("Updates")
            }

            Section {
                LabeledContent("Email") {
                    Text("dyk429@cj.net")
                        .textSelection(.enabled)
                }
                LabeledContent("Slack") {
                    Text("@김도연")
                        .textSelection(.enabled)
                }
            } header: {
                Text("Contact")
            } footer: {
                Text("For bug reports or inquiries, please reach out via Slack DM or email.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .alert(importAlertTitle,
               isPresented: Binding(
                   get: { accountStore.state.importResult != nil },
                   set: { if !$0 { accountStore.send(.dismissImportResult) } }
               )
        ) {
            Button("OK", role: .cancel) {
                accountStore.send(.dismissImportResult)
            }
        } message: {
            Text(importAlertMessage)
        }
    }
}
