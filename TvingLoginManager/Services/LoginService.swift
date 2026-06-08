import Foundation
import WebKit

enum LoginStep: String {
    case navigating = "Navigating..."
    case enteringOTP = "Entering OTP..."
    case clickingLogin = "Opening login page..."
    case enteringCredentials = "Entering credentials..."
    case submitting = "Submitting..."
    case verifying = "Verifying..."
    case success = "Login successful"
    case failed = "Login failed"
}

@MainActor
final class LoginService: NSObject {
    private weak var webView: WKWebView?
    private var account: AccountInfo?
    private var otpCode: String = ""
    private var onStatusUpdate: ((LoginStep, String) -> Void)?
    private var onComplete: ((Bool, String) -> Void)?

    func configure(
        webView: WKWebView,
        account: AccountInfo,
        otpCode: String,
        onStatusUpdate: @escaping (LoginStep, String) -> Void,
        onComplete: @escaping (Bool, String) -> Void
    ) {
        self.webView = webView
        self.account = account
        self.otpCode = otpCode
        self.onStatusUpdate = onStatusUpdate
        self.onComplete = onComplete
    }

    func startLoginSequence() {
        guard let account = account else { return }

        Task { @MainActor in
            do {
                if !otpCode.isEmpty {
                    onStatusUpdate?(.enteringOTP, LoginStep.enteringOTP.rawValue)
                    try await injectOTP(otpCode)
                    try await Task.sleep(for: .seconds(2))
                }

                onStatusUpdate?(.clickingLogin, LoginStep.clickingLogin.rawValue)
                try await clickElement("#locLogin")
                try await Task.sleep(for: .seconds(3))

                onStatusUpdate?(.enteringCredentials, LoginStep.enteringCredentials.rawValue)
                let usernameEntered = try await fillField(
                    selectors: ["input[placeholder=\"아이디\"]", "input#userId"],
                    value: account.username
                )
                guard usernameEntered else {
                    onComplete?(false, "Could not find username field.")
                    return
                }
                try await Task.sleep(for: .seconds(1))

                let passwordEntered = try await fillField(
                    selectors: ["input[placeholder=\"비밀번호\"]", "input#userPwd"],
                    value: account.password
                )
                guard passwordEntered else {
                    onComplete?(false, "Could not find password field.")
                    return
                }
                try await Task.sleep(for: .seconds(1))

                onStatusUpdate?(.submitting, LoginStep.submitting.rawValue)
                try await clickElement("#doLoginBtn", fallback: "button[type='submit']")
                try await Task.sleep(for: .seconds(5))

                onStatusUpdate?(.verifying, LoginStep.verifying.rawValue)
                let success = try await verifyLogin()

                if success {
                    let msg = "Login successful: \(account.title)"
                    onStatusUpdate?(.success, msg)
                    onComplete?(true, msg)
                } else {
                    let msg = "Login completed: \(account.title) (verify manually)"
                    onStatusUpdate?(.verifying, msg)
                    onComplete?(true, msg)
                }
            } catch {
                onComplete?(false, "Login failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func injectOTP(_ code: String) async throws {
        try await executeJS("""
            (function() {
                var f = document.querySelector('#code-num01');
                if (f) {
                    f.value = '\(code.escapedForJS)';
                    f.dispatchEvent(new Event('input', {bubbles:true}));
                    var b = document.querySelector('#confirmBtn');
                    if (b) b.click();
                }
            })()
        """)
    }

    @MainActor
    private func fillField(selectors: [String], value: String) async throws -> Bool {
        let selectorJS = selectors.map { "document.querySelector('\($0)')" }.joined(separator: " || ")
        let result = try await executeJS("""
            (function() {
                var f = \(selectorJS);
                if (f) {
                    f.focus();
                    f.value = '\(value.escapedForJS)';
                    f.dispatchEvent(new Event('input', {bubbles:true}));
                    f.dispatchEvent(new Event('change', {bubbles:true}));
                    return 'ok';
                }
                return 'not_found';
            })()
        """)
        return result == "ok"
    }

    @MainActor
    private func clickElement(_ selector: String, fallback: String? = nil) async throws {
        var js = "document.querySelector('\(selector)')"
        if let fb = fallback {
            js = "(\(js) || document.querySelector('\(fb)'))"
        }
        try await executeJS("(function() { var e = \(js); if (e) e.click(); })()")
    }

    @MainActor
    private func verifyLogin() async throws -> Bool {
        let result = try await executeJS("""
            (function() {
                var t = document.body.innerText || '';
                if (t.includes('로그인 완료')) return 'success';
                if (t.includes('로그인되었습니다')) return 'success';
                if (t.includes('환영합니다')) return 'success';
                if (window.location.href.includes('/main')) return 'success';
                return 'unknown';
            })()
        """)
        return result == "success"
    }

    @MainActor
    @discardableResult
    private func executeJS(_ js: String) async throws -> String {
        guard let webView = webView else { throw LoginError.webViewDeallocated }
        let result = try await webView.evaluateJavaScript(js)
        return (result as? String) ?? ""
    }
}

enum LoginError: LocalizedError {
    case webViewDeallocated
    var errorDescription: String? { "WebView is no longer available" }
}

extension String {
    var escapedForJS: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            .replacingOccurrences(of: "<", with: "\\x3c")
            .replacingOccurrences(of: ">", with: "\\x3e")
    }
}
