import AppKit
import OSLog
import WebKit

/// 메뉴바용: CLI처럼 화면 밖 WebView로 로그인 시퀀스를 돌린다. 한 번에 하나만 돈다.
@MainActor
final class BackgroundLogin: NSObject, WKNavigationDelegate {
    struct Result: Sendable {
        let outcome: LoginOutcome
        let message: String
        let profiles: [ProfileInfo]?
    }

    private static var active: BackgroundLogin?
    /// 실행이 시작되기 전에 들어온 취소 — run()이 시작하자마자 확인한다
    private static var cancelledRunIds: Set<UUID> = []
    private static let log = Logger(subsystem: "com.tving.login-manager", category: "BackgroundLogin")

    static func run(runId: UUID, account: AccountInfo, otp: String, url: URL,
                    timeout: Duration = .seconds(120)) async -> Result {
        let cancelled = String(localized: "Login cancelled.")
        if cancelledRunIds.remove(runId) != nil {
            return Result(outcome: .failed, message: cancelled, profiles: nil)
        }
        active?.finish(.failed, cancelled)
        let login = BackgroundLogin(runId: runId)
        active = login
        defer { if active === login { active = nil } }
        return await withCheckedContinuation { continuation in
            login.continuation = continuation
            login.start(account: account, otp: otp, url: url)
            login.timeoutTask = Task { [weak login] in
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                login?.finish(.failed, String(localized: "Login timed out."))
            }
        }
    }

    static func cancel(runId: UUID) {
        if let active, active.runId == runId {
            active.finish(.failed, String(localized: "Login cancelled."))
        } else {
            cancelledRunIds.insert(runId)
        }
    }

    private let runId: UUID

    private init(runId: UUID) {
        self.runId = runId
        super.init()
    }

    private let service = LoginService()
    private var webView: WKWebView?
    private var window: NSWindow?
    private var hasStarted = false
    private var profiles: [ProfileInfo]?
    private var continuation: CheckedContinuation<Result, Never>?
    private var timeoutTask: Task<Void, Never>?

    private func start(account: AccountInfo, otp: String, url: URL) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        // 화면 밖 창은 WebKit이 '비활성'으로 보고 페이지 실행을 늦출 수 있다 — 예방 차원에서 끈다.
        configuration.preferences.inactiveSchedulingPolicy = .none
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800), configuration: configuration)
        webView.navigationDelegate = self

        // 오프스크린 윈도우에 담아 타이머/렌더링 스로틀링을 피한다 (CLI와 동일). 화면에는 안 뜬다.
        let window = NSWindow(contentRect: webView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isExcludedFromWindowsMenu = true
        window.contentView = webView
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderBack(nil)
        self.webView = webView
        self.window = window

        service.configure(
            webView: webView,
            account: account,
            otpCode: otp,
            onStatusUpdate: { step, _ in Self.log.notice("step: \(step.rawValue, privacy: .public)") },
            onComplete: { [weak self] outcome, message in self?.finish(outcome, message) },
            onProfilesFound: { [weak self] profiles in self?.profiles = profiles }
        )
        Self.log.notice("load: \(url.absoluteString, privacy: .public)")
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasStarted, continuation != nil else { return }
        hasStarted = true
        Self.log.notice("didFinish: \(webView.url?.absoluteString ?? "-", privacy: .public)")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))   // GUI·CLI와 같은 여유
            guard continuation != nil else { return }
            service.startLoginSequence()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // 시퀀스가 시작된 뒤의 실패(다음 페이지로 교체되며 취소 등)는 시퀀스와 타임아웃이 판정한다
        guard !hasStarted, (error as NSError).code != NSURLErrorCancelled else { return }
        finish(.failed, String(localized: "Navigation failed: \(error.localizedDescription)"))
    }

    /// 창 로그인과 같은 규칙: 비밀번호를 넣는 WebView는 https 밖으로 나가지 않는다
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let scheme = navigationAction.request.url?.scheme else { return decisionHandler(.allow) }
        decisionHandler(scheme == "https" || scheme == "about" ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !hasStarted, (error as NSError).code != NSURLErrorCancelled else { return }
        finish(.failed, String(localized: "Navigation failed: \(error.localizedDescription)"))
    }

    private func finish(_ outcome: LoginOutcome, _ message: String) {
        guard let continuation else { return }
        self.continuation = nil
        Self.log.notice("finish: \(String(describing: outcome), privacy: .public) — \(message, privacy: .public)")
        timeoutTask?.cancel()
        service.cancel()
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        window?.orderOut(nil)
        window = nil
        webView = nil
        continuation.resume(returning: Result(outcome: outcome, message: message, profiles: profiles))
    }
}
