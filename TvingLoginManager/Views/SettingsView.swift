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
                Text("Default: https://user.tving.com/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("QC Environment")
            }

            Section {
                TextField("QA Login URL", text: store.binding(\.draftQaLoginURL, send: SettingsAction.setDraftQaLoginURL))
                    .accessibilityIdentifier("settings_qa_url")
                    .textFieldStyle(.roundedBorder)
                Text("Default: https://userqa.tving.com/tv/login/qrcode.tving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    var body: some View {
        Form {
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
                LabeledContent("Build") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-")
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
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}
