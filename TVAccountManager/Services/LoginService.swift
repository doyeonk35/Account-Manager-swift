import Foundation
import WebKit

enum LoginStep: String {
    case navigating = "Navigating..."
    case enteringOTP = "Entering OTP..."
    case clickingLogin = "Opening login page..."
    case enteringCredentials = "Entering credentials..."
    case submitting = "Submitting..."
    case verifying = "Verifying..."
    case success = "Login successful!"
    case failed = "Login failed."
}

@MainActor
final class LoginService: NSObject {
    private weak var webView: WKWebView?
    private var account: AccountInfo?
    private var otpCode: String = ""
    private var onStatusUpdate: ((LoginStep, String) -> Void)?
    private var onComplete: ((Bool, String) -> Void)?
    private var loginTask: Task<Void, Never>?

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

    func cancel() {
        loginTask?.cancel()
        loginTask = nil
    }

    func startLoginSequence() {
        guard let account = account else { return }

        loginTask = Task { @MainActor in
            do {
                // OTP 처리
                if !otpCode.isEmpty {
                    try Task.checkCancellation()
                    onStatusUpdate?(.enteringOTP, LoginStep.enteringOTP.rawValue)
                    try await injectOTP(otpCode)
                    try await Task.sleep(for: .seconds(1))
                }

                // "티빙 아이디로 로그인" 버튼 자동 클릭 시도
                try Task.checkCancellation()
                onStatusUpdate?(.clickingLogin, String(localized: "[\(account.accountType.rawValue.uppercased())] Looking for TVING ID login button..."))
                try await autoClickLoginMethod()

                // ID 입력 필드가 나타날 때까지 대기
                try Task.checkCancellation()
                onStatusUpdate?(.clickingLogin, String(localized: "Waiting for login form..."))
                for _ in 0..<500 {
                    try Task.checkCancellation()
                    let found = (try? await executeJS("""
                        (function() {
                            var f = document.querySelector('input[name="id"]')
                                 || document.querySelector('input[placeholder="아이디"]');
                            return f ? 'found' : 'not_found';
                        })()
                    """)) ?? "not_found"
                    if found == "found" { break }
                    try await Task.sleep(for: .milliseconds(300))
                }

                // 로그인 폼 셀렉터 (아이디/비밀번호 — 입력·재확인 공용)
                let usernameSelectors = [
                    "input[name=\"id\"]",
                    "input[autocomplete=\"username\"]",
                    "input[placeholder=\"아이디\"]",
                ]
                let passwordSelectors = [
                    "input[name=\"password\"]",
                    "input[autocomplete=\"current-password\"]",
                    "input[placeholder=\"비밀번호\"]",
                ]

                // 아이디 입력
                try Task.checkCancellation()
                onStatusUpdate?(.enteringCredentials, String(localized: "Entering username..."))
                guard try await waitAndFill(selectors: usernameSelectors, value: account.username) else {
                    onComplete?(false, String(localized: "Could not find username field."))
                    return
                }
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(300))

                // 비밀번호 입력
                try Task.checkCancellation()
                onStatusUpdate?(.enteringCredentials, String(localized: "Entering password..."))
                guard try await waitAndFill(selectors: passwordSelectors, value: account.password) else {
                    onComplete?(false, String(localized: "Could not find password field."))
                    return
                }

                // "로그인" 버튼 클릭 전 최종 확인: 제출 직전 React가 필드를 비웠으면 한 번 더 채운다
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(300))
                if try await isFieldEmpty(usernameSelectors) {
                    _ = try await waitAndFill(selectors: usernameSelectors, value: account.username)
                }
                if try await isFieldEmpty(passwordSelectors) {
                    _ = try await waitAndFill(selectors: passwordSelectors, value: account.password)
                }
                let usernameFilled = !(try await isFieldEmpty(usernameSelectors))
                let passwordFilled = !(try await isFieldEmpty(passwordSelectors))
                guard usernameFilled, passwordFilled else {
                    onComplete?(false, String(localized: "Login form was cleared before submit. Please try again."))
                    return
                }

                // "로그인" 버튼 자동 클릭 시도
                onStatusUpdate?(.submitting, String(localized: "Clicking login button..."))
                let loginClicked = try await autoClickLoginSubmit()

                let env = account.accountType.rawValue.uppercased()
                if loginClicked {
                    onStatusUpdate?(.success, String(localized: "[\(env)] \(account.title) — Login submitted"))
                    onComplete?(true, String(localized: "[\(env)] \(account.title) — Login submitted"))
                } else {
                    onStatusUpdate?(.enteringCredentials, String(localized: "[\(env)] \(account.title) — Credentials filled. Please click Login."))
                    onComplete?(true, String(localized: "[\(env)] \(account.title) — Credentials filled"))
                }
            } catch is CancellationError {
                // Sheet dismissed — silently stop
            } catch {
                let env = account.accountType.rawValue.uppercased()
                onComplete?(false, String(localized: "[\(env)] \(account.title) — Login failed: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - OTP

    private func injectOTP(_ code: String) async throws {
        // #code-num01 필드가 나타날 때까지 대기 (최대 10초)
        for _ in 0..<20 {
            try Task.checkCancellation()
            let found = (try? await executeJS("""
                (function() { return document.querySelector('#code-num01') ? 'found' : 'not_found'; })()
            """)) ?? "not_found"
            if found == "found" { break }
            try await Task.sleep(for: .milliseconds(500))
        }

        // OTP 6자리를 #code-num01 ~ #code-num06 각 필드에 한 자리씩 입력
        // 이 페이지는 바닐라 JS (oninput="add(this)") 사용
        let digits = Array(code.prefix(6))
        for (i, digit) in digits.enumerated() {
            try Task.checkCancellation()
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
        onStatusUpdate?(.enteringOTP, String(localized: "Clicking confirm..."))
        try await clickElement("#confirmBtn")

        // 페이지 이동 대기 (최대 100초, 자동 실패 시 사용자가 직접 클릭 가능)
        onStatusUpdate?(.enteringOTP, String(localized: "OTP submitted. Waiting for next page..."))
        for _ in 0..<200 {
            try Task.checkCancellation()
            let stillOnOTP = (try? await executeJS("""
                (function() { return document.querySelector('#code-num01') ? 'yes' : 'no'; })()
            """)) ?? "no"
            if stillOnOTP == "no" { break }
            try await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - Auto-click login method ("티빙 아이디로 로그인")

    private func autoClickLoginMethod() async throws {
        for _ in 0..<75 {
            try Task.checkCancellation()
            let result = (try? await executeJS("""
                (function() {
                    var link = document.querySelector('a[data-sentry-component="TvingIdLoginButton"]');
                    if (link) { link.click(); return 'clicked'; }
                    var btn = document.querySelector('button[aria-label="티빙 아이디로 로그인"]');
                    if (btn) { btn.click(); return 'clicked'; }
                    var byHref = document.querySelector('a[href*="/account/login/tving"]');
                    if (byHref) { byHref.click(); return 'clicked'; }
                    var els = document.querySelectorAll('a, button');
                    for (var i = 0; i < els.length; i++) {
                        var t = (els[i].textContent || '').trim();
                        if (t.includes('티빙 아이디') && t.includes('로그인')) {
                            els[i].click();
                            return 'clicked';
                        }
                    }
                    return 'not_found';
                })()
            """)) ?? "not_found"
            if result == "clicked" { return }
            try await Task.sleep(for: .milliseconds(300))
        }
    }

    // MARK: - Auto-click login submit ("로그인")

    private func autoClickLoginSubmit() async throws -> Bool {
        for _ in 0..<25 {
            try Task.checkCancellation()
            let result = (try? await executeJS("""
                (function() {
                    var submit = document.querySelector('button[type="submit"][data-sentry-source-file="LoginLayer.tsx"]');
                    if (submit) { submit.click(); return 'clicked'; }
                    submit = document.querySelector('form button[type="submit"]');
                    if (submit) { submit.click(); return 'clicked'; }
                    submit = document.querySelector('button[type="submit"]');
                    if (submit) { submit.click(); return 'clicked'; }
                    var btns = document.querySelectorAll('button');
                    for (var i = 0; i < btns.length; i++) {
                        var t = (btns[i].textContent || '').trim();
                        if (t === '로그인' || t === 'Login') {
                            btns[i].click();
                            return 'clicked';
                        }
                    }
                    return 'not_found';
                })()
            """)) ?? "not_found"
            if result == "clicked" { return true }
            try await Task.sleep(for: .milliseconds(300))
        }
        return false
    }

    // MARK: - Wait + Fill (React 호환)

    /// 셀렉터 중 첫 매칭 필드의 값이 비어 있으면 true. 필드를 못 찾아도 비었다고 간주한다.
    private func isFieldEmpty(_ selectors: [String]) async throws -> Bool {
        let selectorJS = selectors.map { "document.querySelector('\($0)')" }.joined(separator: " || ")
        let value = (try? await executeJS("""
            (function() {
                var f = \(selectorJS);
                return (f && f.value) ? f.value : '';
            })()
        """)) ?? ""
        return value.isEmpty
    }

    /// 셀렉터에 해당하는 엘리먼트가 나타나고, 입력값이 실제로 유지될 때까지 재시도하며 값 입력.
    /// React 컨트롤드 인풋은 필드가 DOM에 나타난 직후 마운트/재렌더되며 값을 되돌리므로,
    /// "값을 넣었다"만으로는 부족하다. 넣은 뒤 재렌더 여유를 두고 값이 남아 있는지 확인하고,
    /// 되돌아갔으면 재시도한다. (아이디·비밀번호 공용)
    private func waitAndFill(selectors: [String], value: String) async throws -> Bool {
        let selectorJS = selectors.map { "document.querySelector('\($0)')" }.joined(separator: " || ")
        let escaped = value.escapedForJS

        let fillJS = """
            (function() {
                var f = \(selectorJS);
                if (!f) return 'not_found';
                if (f.disabled || f.readOnly) return 'not_ready';

                f.focus();

                // React 호환: nativeInputValueSetter로 값 설정
                var nativeSetter = Object.getOwnPropertyDescriptor(
                    window.HTMLInputElement.prototype, 'value'
                ).set;
                nativeSetter.call(f, '\(escaped)');

                // 이벤트 디스패치 — React, Vue, Angular 모두 대응
                f.dispatchEvent(new Event('input', {bubbles: true}));
                f.dispatchEvent(new Event('change', {bubbles: true}));
                f.dispatchEvent(new KeyboardEvent('keydown', {bubbles: true}));
                f.dispatchEvent(new KeyboardEvent('keyup', {bubbles: true}));

                return 'filled';
            })()
        """
        // 재렌더 후 값이 남아 있는지 확인
        let verifyJS = """
            (function() {
                var f = \(selectorJS);
                if (!f) return 'gone';
                return f.value === '\(escaped)' ? 'ok' : 'reset';
            })()
        """

        // 필드가 나타나고 값이 유지될 때까지 재시도 (~16초: 30회 × (fill + 250ms + 300ms))
        for _ in 0..<30 {
            try Task.checkCancellation()
            let filled = (try? await executeJS(fillJS)) ?? "not_found"
            if filled == "filled" {
                // React 재렌더가 값을 되돌리는지 확인할 여유
                try await Task.sleep(for: .milliseconds(250))
                let verified = (try? await executeJS(verifyJS)) ?? "gone"
                if verified == "ok" { return true }
            }
            try await Task.sleep(for: .milliseconds(300))
        }
        return false
    }

    // MARK: - Click

    /// 여러 셀렉터를 순서대로 시도하여 클릭 (최대 10초 대기)
    private func waitAndClick(selectors: [String]) async throws -> Bool {
        let selectorJS = selectors.map { "document.querySelector('\($0)')" }.joined(separator: " || ")
        for _ in 0..<20 {
            let result = (try? await executeJS("""
                (function() {
                    var e = \(selectorJS);
                    if (e) { e.click(); return 'clicked'; }
                    return 'not_found';
                })()
            """)) ?? "not_found"
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
        _ = try? await executeJS("(function() { var e = \(js); if (e) e.click(); })()")
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
