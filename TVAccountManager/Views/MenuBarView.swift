import SwiftUI

/// 메뉴바 패널: OTP 입력 + 계정 최대 3개. 로그인은 창 없이 백그라운드로 돈다.
struct MenuBarView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var router: AppRouter
    @Environment(\.openWindow) private var openWindow

    private var isOtpComplete: Bool { store.state.otpCode.count == 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("OTP Code")
                    .font(.headline)
                Spacer()
                if settingsStore.state.isUsingProdURL {
                    ProductionBadge()
                }
            }

            OTPField()
                .textFieldStyle(.roundedBorder)
                .font(.system(.title3, design: .monospaced).bold())
                .accessibilityIdentifier("menubar_otp_field")

            Divider()

            if store.state.menuBarAccounts.isEmpty {
                Text("No Accounts")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.state.menuBarAccounts) { account in
                    accountRow(account)
                }
            }

            if !store.state.loginStatus.isEmpty {
                Divider()
                statusRow
            }

            Divider()

            HStack {
                Button("Open Main Window") {
                    showMainWindow()
                }
                .help(Text("Open the account list and settings"))
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .help(Text("Quit TVAccountManager"))
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 320)
    }

    private func accountRow(_ account: AccountInfo) -> some View {
        HStack(spacing: 8) {
            if account.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(Text("Pinned to top"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.title.isEmpty ? account.username : account.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(account.accountType.rawValue) · \(account.planType.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.state.backgroundLoginAccountId == account.id {
                ProgressView()
                    .controlSize(.small)
                Button("Cancel") {
                    store.send(.cancelBackgroundLogin)
                }
                .help(Text("Stop this login"))
            } else {
                Button("Login") {
                    store.send(.startBackgroundLogin(account))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isOtpComplete || store.state.isLoggingIn)
                .accessibilityIdentifier("menubar_login_\(account.title)")
                .help(isOtpComplete
                      ? Text("Log in without opening a window")
                      : Text("Enter the 6-digit OTP code first"))
            }
        }
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.state.loginStatus)
                .font(.footnote)
                .foregroundStyle(store.state.isLoggingIn ? .orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let id = store.state.windowLoginFallbackId,
               let account = store.state.accounts.first(where: { $0.id == id }) {
                Button("Log In in Window") {
                    showMainWindow()
                    store.send(.startLogin(account))
                }
                .controlSize(.small)
                .help(Text("Continue in the login window, where you can pick a profile yourself. You may need a new OTP code."))
            }
        }
    }

    private func showMainWindow() {
        openWindow(id: MainWindow.id)
        NSApp.activate()
    }
}

/// QC 계정이 운영 URL로 로그인하는 상태를 눈에 띄게 표시한다.
struct ProductionBadge: View {
    var body: some View {
        Text("QC → Production")
            .font(.caption.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.18))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help(Text("QC accounts log in with the production URL."))
    }
}
