import SwiftUI
import Sparkle
import ServiceManagement

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
                Picker("Login Server", selection: Binding(
                    get: { store.state.qcUsesProduction },
                    set: { store.send(.setQcUsesProduction($0)) }
                )) {
                    Text("Development").tag(false)
                    Text("Production").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings_qc_target")
                .help(Text("Choose which server QC accounts log in to. Applies immediately."))

                if store.state.qcUsesProduction {
                    LabeledContent("Production URL") {
                        Text(verbatim: SettingsState.prodURL)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
                URLField(
                    title: "Development URL",
                    text: store.binding(\.draftQcLoginURL, send: SettingsAction.setDraftQcLoginURL),
                    defaultURL: SettingsState.defaultQcURL,
                    identifier: "settings_qc_url"
                )
            } header: {
                Text("QC Environment")
            } footer: {
                if store.state.qcUsesProduction {
                    Text("QC accounts log in to production. Your development URL is kept for when you switch back.")
                }
            }

            Section {
                URLField(
                    title: "Login URL",
                    text: store.binding(\.draftQaLoginURL, send: SettingsAction.setDraftQaLoginURL),
                    defaultURL: SettingsState.defaultQaURL,
                    identifier: "settings_qa_url"
                )
            } header: {
                Text("QA Environment")
            }

            Section {
                HStack {
                    Button("Reset to Defaults") {
                        store.send(.resetToDefaults)
                    }
                    .accessibilityIdentifier("settings_reset")
                    .controlSize(.small)
                    .help(Text("Use the app's default URLs and the development server. Defaults follow app updates."))

                    Spacer()

                    Button("Save") {
                        store.send(.saveChanges)
                    }
                    .accessibilityIdentifier("settings_save")
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.state.canSave)
                    .keyboardShortcut("s", modifiers: .command)
                    .help(Text("Save URL changes (⌘S)"))
                }
            } footer: {
                Text("URLs left at their default follow app updates automatically.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Environment")
        .onAppear {
            store.send(.beginEditing)
        }
    }
}

/// 로그인 URL 입력칸: 검증 안내 + 기본값 사용 여부 + 기본값으로 되돌리기
private struct URLField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let defaultURL: String
    let identifier: String

    var body: some View {
        TextField(title, text: $text)
            .accessibilityIdentifier(identifier)
            .textFieldStyle(.roundedBorder)
        if !SettingsState.isValidLoginURL(text) {
            Label("Enter a full https:// URL.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
        HStack {
            if text.trimmingCharacters(in: .whitespaces) == defaultURL {
                Label("Using the default URL", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Default: \(defaultURL)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer()
                Button("Use Default") { text = defaultURL }
                    .controlSize(.small)
                    .help(Text("Fill in the app's default URL. Save to apply."))
            }
        }
    }
}

// MARK: - General Settings

struct SettingsGeneralView: View {
    let updater: SPUUpdater
    @EnvironmentObject var accountStore: AccountStore
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?
    @State private var updaterRefresh = false   // Sparkle 값이 바뀌면 다시 그리게 하는 신호

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        if SMAppService.mainApp.status == .requiresApproval {
            launchAtLoginError = String(localized: "Allow the app in System Settings › General › Login Items.")
            SMAppService.openSystemSettingsLoginItems()
        }
        // 실패하거나 사용자 승인 대기면 실제 상태로 되돌린다
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

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

    private var exportAlertTitle: LocalizedStringKey {
        guard let result = accountStore.state.exportResult else { return "" }
        switch result {
        case .success: return "Export Complete"
        case .failure: return "Export Failed"
        }
    }

    private var exportAlertMessage: LocalizedStringKey {
        guard let result = accountStore.state.exportResult else { return "" }
        switch result {
        case .success(let url, let count, let includedPasswords):
            return includedPasswords
                ? "\(count) accounts exported with passwords to \(url.lastPathComponent)."
                : "\(count) accounts exported without passwords to \(url.lastPathComponent)."
        case .failure(let message):
            return "Failed to write the export file: \(message)"
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
                .help(Text("Open the folder that holds presets.json and the example file"))

                Button {
                    accountStore.send(.importPresets)
                } label: {
                    Label("Import Accounts from File", systemImage: "tray.and.arrow.down")
                }
                .accessibilityIdentifier("settings_import_presets")
                .help(Text("Add accounts from presets.json. Existing accounts are skipped."))

                Button {
                    accountStore.send(.startExport)
                } label: {
                    Label("Export Accounts to File", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("settings_export_accounts")
                .help(Text("Save all accounts to a file you can import on another Mac"))
                .disabled(accountStore.state.accounts.isEmpty)
                .confirmationDialog("Export Accounts?",
                                    isPresented: Binding(
                                        get: { accountStore.state.isConfirmingExport },
                                        set: { if !$0 { accountStore.send(.cancelExport) } }
                                    ),
                                    titleVisibility: .visible
                ) {
                    Button("Include Passwords") {
                        accountStore.send(.exportAccounts(includePasswords: true))
                    }
                    Button("Exclude Passwords") {
                        accountStore.send(.exportAccounts(includePasswords: false))
                    }
                    Button("Cancel", role: .cancel) {
                        accountStore.send(.cancelExport)
                    }
                } message: {
                    Text("Including passwords writes them to the file as plain text.")
                }
                .alert(exportAlertTitle,
                       isPresented: Binding(
                           get: { accountStore.state.exportResult != nil },
                           set: { if !$0 { accountStore.send(.dismissExportResult) } }
                       )
                ) {
                    Button("OK", role: .cancel) {
                        // 알럿을 닫은 뒤에 드러낸다 — Finder가 먼저 올라오면 알럿이 뒤로 밀린다
                        let url = accountStore.state.exportedFileURL
                        accountStore.send(.dismissExportResult)
                        if let url {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                } message: {
                    Text(exportAlertMessage)
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Open the folder to find presets.example.json with the format. Rename it to presets.json and fill in your accounts.")
            }

            Section {
                Toggle("Show in Menu Bar", isOn: $showMenuBarExtra)
                    .accessibilityIdentifier("settings_show_menubar")
                    .help(Text("Show the OTP field and up to 3 accounts in the menu bar"))
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: setLaunchAtLogin
                ))
                .accessibilityIdentifier("settings_launch_at_login")
                .help(Text("Start in the menu bar when you log in to your Mac"))
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("The menu bar shows the OTP field and up to 3 accounts: pinned accounts first, then recently used ones.")
            }

            Section {
                Button {
                    NotificationCenter.default.post(name: .showOnboarding, object: nil)
                } label: {
                    Label("View Usage Guide", systemImage: "questionmark.circle")
                }
                .accessibilityIdentifier("settings_show_guide")
                .help(Text("Show the first-run guide again"))
            } header: {
                Text("Help")
            }

            Section {
                LabeledContent("Version") {
                    Text(verbatim: Self.versionText)
                        .textSelection(.enabled)
                }
            } header: {
                Text("App Info")
            }

            Section {
                Toggle("Check for Updates Automatically", isOn: Binding(
                    get: { _ = updaterRefresh; return updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0; updaterRefresh.toggle() }
                ))
                .accessibilityIdentifier("settings_auto_update")
                .help(Text("Check for new versions in the background and offer to install them"))
                CheckForUpdatesView(
                    viewModel: CheckForUpdatesViewModel(updater: updater)
                )
                .help(Text("Check for a new version now"))
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
