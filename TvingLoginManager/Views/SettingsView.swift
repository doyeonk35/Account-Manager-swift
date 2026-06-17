import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: AccountManager

    var body: some View {
        Form {
            Section {
                TextField("QC Login URL", text: $manager.qcLoginURL)
                    .textFieldStyle(.roundedBorder)
                Text("Default: https://user.tving.com/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("QC Environment")
            }

            Section {
                TextField("QA Login URL", text: $manager.qaLoginURL)
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
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
