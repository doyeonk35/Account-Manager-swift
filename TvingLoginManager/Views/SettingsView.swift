import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: AccountManager

    var body: some View {
        Form {
            Section {
                TextField("QC Login URL", text: $manager.qcLoginURL)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("QC Environment")
            } footer: {
                Text("Default: https://user.tving.com/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("QA Login URL", text: $manager.qaLoginURL)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("QA Environment")
            } footer: {
                Text("Default: https://userqa.tving.com/tv/login/qrcode.tving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset to Defaults") {
                    manager.qcLoginURL = "https://user.tving.com/"
                    manager.qaLoginURL = "https://userqa.tving.com/tv/login/qrcode.tving"
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
