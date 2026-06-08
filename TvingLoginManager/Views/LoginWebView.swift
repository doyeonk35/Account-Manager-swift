import SwiftUI

struct LoginWebView: View {
    @EnvironmentObject var manager: AccountManager
    let account: AccountInfo
    let otpCode: String

    var body: some View {
        VStack {
            Text("Login WebView — will be implemented in Task 9")
                .font(.headline)
            Text("Account: \(account.title)")
            Button("Close") { manager.dismissLoginWebView() }
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
