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
                url: manager.loginURL(for: account.accountType),
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

        // 네트워크 요청 모니터링 스크립트 주입
        let monitorScript = WKUserScript(source: """
            (function() {
                // fetch 가로채기
                var origFetch = window.fetch;
                window.fetch = function(url, opts) {
                    var method = (opts && opts.method) || 'GET';
                    var body = (opts && opts.body) || '';
                    console.log('[NETWORK] ' + method + ' ' + url);
                    if (body) console.log('[BODY] ' + (typeof body === 'string' ? body : JSON.stringify(body)));
                    return origFetch.apply(this, arguments);
                };

                // XMLHttpRequest 가로채기
                var origOpen = XMLHttpRequest.prototype.open;
                var origSend = XMLHttpRequest.prototype.send;
                XMLHttpRequest.prototype.open = function(method, url) {
                    this._method = method;
                    this._url = url;
                    return origOpen.apply(this, arguments);
                };
                XMLHttpRequest.prototype.send = function(body) {
                    console.log('[NETWORK] ' + this._method + ' ' + this._url);
                    if (body) console.log('[BODY] ' + body);
                    return origSend.apply(this, arguments);
                };
            })();
            """, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(monitorScript)

        // console.log를 Swift에서 수신
        config.userContentController.add(context.coordinator, name: "logHandler")
        let consoleScript = WKUserScript(source: """
            var origLog = console.log;
            console.log = function() {
                var msg = Array.from(arguments).join(' ');
                origLog.apply(console, arguments);
                window.webkit.messageHandlers.logHandler.postMessage(msg);
            };
            """, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(consoleScript)

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

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let body = message.body as? String {
                print("🌐 \(body)")
            }
        }

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
