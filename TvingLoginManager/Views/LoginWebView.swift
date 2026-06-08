import SwiftUI
import WebKit

struct LoginWebView: View {
    @EnvironmentObject var manager: AccountManager
    let account: AccountInfo
    let otpCode: String

    @State private var currentStep = "Preparing..."
    @State private var isLoginDone = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Logging in: \(account.title)")
                        .font(.headline)
                    Text(currentStep)
                        .font(.subheadline)
                        .foregroundStyle(isLoginDone ? .green : .orange)
                }
                Spacer()
                Button("Close") {
                    manager.dismissLoginWebView()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)

            Divider()

            WebViewContainer(
                url: account.loginURL,
                account: account,
                otpCode: otpCode,
                onStatusUpdate: { _, message in
                    currentStep = message
                },
                onComplete: { success, message in
                    isLoginDone = true
                    currentStep = message
                    manager.loginCompleted(success: success, message: message)
                }
            )
        }
    }
}

struct WebViewContainer: NSViewRepresentable {
    let url: URL
    let account: AccountInfo
    let otpCode: String
    let onStatusUpdate: (LoginStep, String) -> Void
    let onComplete: (Bool, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.loginService.configure(
            webView: webView,
            account: account,
            otpCode: otpCode,
            onStatusUpdate: onStatusUpdate,
            onComplete: onComplete
        )

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let loginService = LoginService()
        private var hasStartedLogin = false
        private let onComplete: (Bool, String) -> Void

        init(onComplete: @escaping (Bool, String) -> Void) {
            self.onComplete = onComplete
            super.init()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasStartedLogin else { return }
            hasStartedLogin = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.loginService.startLoginSequence()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onComplete(false, "Navigation failed: \(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               url.scheme != "https" && url.scheme != "about" {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
