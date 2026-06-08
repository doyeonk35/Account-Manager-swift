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

                // 사용자가 "티빙 아이디로 로그인"을 직접 클릭할 때까지 대기
                onStatusUpdate?(.clickingLogin, "'티빙 아이디로 로그인' 버튼을 눌러주세요.")
                for _ in 0..<200 {
                    let found = try await executeJS("""
                        (function() {
                            var f = document.querySelector("input[name='id']")
                                 || document.querySelector("input[placeholder='아이디']");
                            return f ? 'found' : 'not_found';
                        })()
                    """)
                    if found == "found" { break }
                    try await Task.sleep(for: .milliseconds(500))
                }

                // 아이디 입력
                onStatusUpdate?(.enteringCredentials, "Entering username...")
                let usernameEntered = try await waitAndFill(
                    selectors: [
                        "input[name='id']",
                        "input[autocomplete='username']",
                        "input[placeholder='아이디']",
                    ],
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
                    selectors: [
                        "input[name='password']",
                        "input[autocomplete='current-password']",
                        "input[placeholder='비밀번호']",
                    ],
                    value: account.password
                )
                guard passwordEntered else {
                    onComplete?(false, "Could not find password field.")
                    return
                }

                // 자동완성 완료 안내
                onStatusUpdate?(.enteringCredentials, "ID/PW 입력 완료. 로그인 버튼을 눌러주세요.")
                onComplete?(true, "Credentials filled: \(account.title)")
            } catch {
                onComplete?(false, "Login failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - OTP

    private func injectOTP(_ code: String) async throws {
        // #code-num01 필드가 나타날 때까지 대기 (최대 10초)
        for _ in 0..<20 {
            let found = try await executeJS("""
                (function() { return document.querySelector('#code-num01') ? 'found' : 'not_found'; })()
            """)
            if found == "found" { break }
            try await Task.sleep(for: .milliseconds(500))
        }

        // OTP 6자리를 #code-num01 ~ #code-num06 각 필드에 한 자리씩 입력
        // 이 페이지는 바닐라 JS (oninput="add(this)") 사용
        let digits = Array(code.prefix(6))
        for (i, digit) in digits.enumerated() {
            let fieldId = String(format: "#code-num%02d", i + 1)
            try await executeJS("""
                (function() {
                    var f = document.querySelector('\(fieldId)');
                    if (f) {
                        f.focus();
                        f.value = '\(String(digit).escapedForJS)';
                        // oninput="add(this)" 한 번만 트리거
                        f.dispatchEvent(new Event('input', {bubbles: true}));
                    }
                })()
            """)
            try await Task.sleep(for: .milliseconds(150))
        }

        // "계속" 버튼 자동 클릭
        try await Task.sleep(for: .milliseconds(500))
        onStatusUpdate?(.enteringOTP, "Clicking confirm...")
        try await clickElement("#confirmBtn")

        // 페이지 이동 대기 (최대 100초, 자동 실패 시 사용자가 직접 클릭 가능)
        onStatusUpdate?(.enteringOTP, "OTP submitted. Waiting for next page...")
        for _ in 0..<200 {
            let stillOnOTP = try await executeJS("""
                (function() { return document.querySelector('#code-num01') ? 'yes' : 'no'; })()
            """)
            if stillOnOTP == "no" { break }
            try await Task.sleep(for: .milliseconds(500))
        }
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

    /// 여러 셀렉터를 순서대로 시도하여 클릭 (최대 10초 대기)
    private func waitAndClick(selectors: [String]) async throws -> Bool {
        let selectorJS = selectors.map { "document.querySelector('\($0)')" }.joined(separator: " || ")
        for _ in 0..<20 {
            let result = try await executeJS("""
                (function() {
                    var e = \(selectorJS);
                    if (e) { e.click(); return 'clicked'; }
                    return 'not_found';
                })()
            """)
            if result == "clicked" { return true }
            try await Task.sleep(for: .milliseconds(500))
        }
        return false
    }

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
