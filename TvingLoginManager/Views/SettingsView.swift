import SwiftUI
import Sparkle

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case environment = "Environment"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .environment: "link"
        }
    }
}

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
    @EnvironmentObject var manager: AccountManager

    var body: some View {
        Form {
            Section {
                TextField("QC Login URL", text: $manager.qcLoginURL)
                    .accessibilityIdentifier("settings_qc_url")
                    .textFieldStyle(.roundedBorder)
                Text("Default: https://user.tving.com/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("QC Environment")
            }

            Section {
                TextField("QA Login URL", text: $manager.qaLoginURL)
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
                    Spacer()
                    Button("Reset to Defaults") {
                        manager.qcLoginURL = "https://user.tving.com/"
                        manager.qaLoginURL = "https://userqa.tving.com/tv/login/qrcode.tving"
                    }
                    .accessibilityIdentifier("settings_reset")
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Environment")
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
