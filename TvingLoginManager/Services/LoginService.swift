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
                // OTP 처리
                if !otpCode.isEmpty {
                    onStatusUpdate?(.enteringOTP, LoginStep.enteringOTP.rawValue)
                    try await injectOTP(otpCode)
                    try await Task.sleep(for: .seconds(2))
                }

                // 로그인 페이지 이동 버튼 클릭
                onStatusUpdate?(.clickingLogin, LoginStep.clickingLogin.rawValue)
                try await clickElement("#locLogin")
                try await Task.sleep(for: .seconds(3))

                // 아이디 입력 — 엘리먼트가 나타날 때까지 대기
                onStatusUpdate?(.enteringCredentials, "Entering username...")
                let usernameEntered = try await waitAndFill(
                    selectors: ["input[placeholder=\"아이디\"]", "input#userId"],
                    value: account.username
                )
                guard usernameEntered else {
                    onComplete?(false, "Could not find username field.")
                    return
                }
                try await Task.sleep(for: .seconds(1))

                // 비밀번호 입력
                onStatusUpdate?(.enteringCredentials, "Entering password...")
                let passwordEntered = try await waitAndFill(
                    selectors: ["input[placeholder=\"비밀번호\"]", "input#userPwd"],
                    value: account.password
                )
                guard passwordEntered else {
                    onComplete?(false, "Could not find password field.")
                    return
                }
                try await Task.sleep(for: .seconds(1))

                // 로그인 제출
                onStatusUpdate?(.submitting, LoginStep.submitting.rawValue)
                try await clickElement("#doLoginBtn", fallback: "button[type='submit']")
                try await Task.sleep(for: .seconds(5))

                // 결과 확인
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

    // MARK: - OTP

    private func injectOTP(_ code: String) async throws {
        // OTP 6자리를 #code-num01 ~ #code-num06 각 필드에 한 자리씩 입력
        let digits = Array(code.prefix(6))
        for (i, digit) in digits.enumerated() {
            let fieldId = String(format: "#code-num%02d", i + 1)
            try await executeJS("""
                (function() {
                    var f = document.querySelector('\(fieldId)');
                    if (f) {
                        f.focus();
                        var ns = Object.getOwnPropertyDescriptor(
                            window.HTMLInputElement.prototype, 'value'
                        ).set;
                        ns.call(f, '\(String(digit).escapedForJS)');
                        f.dispatchEvent(new Event('input', {bubbles: true}));
                        f.dispatchEvent(new Event('change', {bubbles: true}));
                    }
                })()
            """)
        }
        // 확인 버튼 클릭
        try await Task.sleep(for: .milliseconds(500))
        try await clickElement("#confirmBtn")
    }

    // MARK: - Wait + Fill (React 호환)

    /// 셀렉터에 해당하는 엘리먼트가 나타날 때까지 최대 10초 대기 후 값 입력
    private func waitAndFill(selectors: [String], value: String) async throws -> Bool {
        let selectorJS = selectors.map { "document.querySelector('\($0)')" }.joined(separator: " || ")

        // 엘리먼트 대기 (500ms 간격, 최대 20회 = 10초)
        for _ in 0..<20 {
            let found = try await executeJS("""
                (function() {
                    var f = \(selectorJS);
                    return f ? 'found' : 'not_found';
                })()
            """)
            if found == "found" { break }
            try await Task.sleep(for: .milliseconds(500))
        }

        // React/Vue 호환 값 입력
        let result = try await executeJS("""
            (function() {
                var f = \(selectorJS);
                if (!f) return 'not_found';

                f.focus();

                // React 호환: nativeInputValueSetter로 값 설정
                var nativeSetter = Object.getOwnPropertyDescriptor(
                    window.HTMLInputElement.prototype, 'value'
                ).set;
                nativeSetter.call(f, '\(value.escapedForJS)');

                // 이벤트 디스패치 — React, Vue, Angular 모두 대응
                f.dispatchEvent(new Event('input', {bubbles: true}));
                f.dispatchEvent(new Event('change', {bubbles: true}));
                f.dispatchEvent(new KeyboardEvent('keydown', {bubbles: true}));
                f.dispatchEvent(new KeyboardEvent('keyup', {bubbles: true}));

                return 'ok';
            })()
        """)
        return result == "ok"
    }

    // MARK: - Click

    private func clickElement(_ selector: String, fallback: String? = nil) async throws {
        var js = "document.querySelector('\(selector)')"
        if let fb = fallback {
            js = "(\(js) || document.querySelector('\(fb)'))"
        }
        try await executeJS("(function() { var e = \(js); if (e) e.click(); })()")
    }

    // MARK: - Verify

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

    // MARK: - JS Execution

    @discardableResult
    private func executeJS(_ js: String) async throws -> String {
        guard let webView = webView else { throw LoginError.webViewDeallocated }
        let result = try await webView.evaluateJavaScript(js)
        return (result as? String) ?? ""
    }

    // MARK: - React 호환 value setter JS 생성

    /// React의 synthetic event 시스템을 우회하여 input value를 설정하는 JS 코드 조각
    private func reactSetValue(_ varName: String, _ value: String) -> String {
        """
        var _ns = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
        _ns.call(\(varName), '\(value)');
        \(varName).dispatchEvent(new Event('input', {bubbles: true}));
        \(varName).dispatchEvent(new Event('change', {bubbles: true}));
        """
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
