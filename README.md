# TVING Login Manager

[한국어](#한국어) | [English](#english)

---

## 한국어

TVING QC/QA 환경을 위한 macOS 계정 관리 및 자동 로그인 앱입니다.

### 기능

- **멀티 계정 관리** — 추가 / 수정 / 삭제
- **환경 구분** — QC / QA 로그인 URL 분리
- **요금제 태그** — 베이직 / 광고 요금제 / 스탠다드 / 프리미엄
- **OTP 자동 입력** — 6자리 코드 자동 분배 입력
- **ID/PW 자동 완성** — React 호환 nativeInputValueSetter 방식
- **비밀번호 보안** — macOS Keychain 저장 (JSON에 평문 미포함)
- **커스텀 로그인 URL** — Settings에서 QC/QA URL 변경 가능
- **다크/라이트 모드** — 시스템 설정 자동 대응

### 요구사항

- macOS 14.0 (Sonoma) 이상
- Xcode 15.0 이상 (빌드 시)

### 설치

#### GitHub Releases
1. [Releases](https://github.com/doyeonk35/TVING-Login-Manager-swift/releases) 페이지에서 `TvingLoginManager.zip` 다운로드
2. 압축 해제 후 `TvingLoginManager.app`을 `/Applications`로 이동

#### 소스에서 빌드
```bash
git clone https://github.com/doyeonk35/TVING-Login-Manager-swift.git
cd TVING-Login-Manager-swift

# xcodegen 필요 (brew install xcodegen)
xcodegen generate
xcodebuild build -project TvingLoginManager.xcodeproj -scheme TvingLoginManager -configuration Release -destination 'platform=macOS'

# 또는 릴리스 zip 생성
./scripts/build-release.sh
```

### 사용 방법

1. 앱 실행 → **+** 버튼 (또는 `Cmd+N`)으로 계정 추가
2. 타이틀, TVING ID, 비밀번호, 환경(QC/QA), 요금제 선택 후 저장
3. OTP 코드 입력 (필요 시)
4. **Login** 버튼 클릭 → WebView에서 자동 로그인 진행
   - OTP 자동 입력 → "계속" 자동 클릭
   - "티빙 아이디로 로그인" → **사용자 직접 클릭**
   - ID/PW 자동 완성 → "로그인" → **사용자 직접 클릭**

### 데이터 저장

| 항목 | 위치 |
|------|------|
| 계정 메타데이터 | `~/Library/Application Support/tving-login-manager/accounts.json` |
| 비밀번호 | macOS Keychain (`com.tving.login-manager`) |
| 로그인 URL 설정 | UserDefaults |

### 기술 스택

| 구분 | 기술 |
|------|------|
| UI | SwiftUI (Form, List, NavigationSplitView) |
| 브라우저 자동화 | WKWebView + JavaScript injection |
| 보안 | Security.framework (Keychain Services) |
| 직렬화 | Codable + JSONEncoder/Decoder |
| 프로젝트 생성 | XcodeGen |

---

## English

A macOS account management and auto-login app for TVING QC/QA environments.

### Features

- **Multi-account management** — Add / Edit / Delete
- **Environment separation** — QC / QA login URLs
- **Plan tags** — Basic / Ad-supported / Standard / Premium
- **OTP auto-fill** — Distributes 6 digits across individual input fields
- **ID/PW auto-fill** — React-compatible nativeInputValueSetter
- **Password security** — Stored in macOS Keychain (not in JSON)
- **Custom login URLs** — Configurable in Settings
- **Dark/Light mode** — Follows system appearance

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)

### Installation

#### GitHub Releases
1. Download `TvingLoginManager.zip` from the [Releases](https://github.com/doyeonk35/TVING-Login-Manager-swift/releases) page
2. Extract and move `TvingLoginManager.app` to `/Applications`

#### Build from Source
```bash
git clone https://github.com/doyeonk35/TVING-Login-Manager-swift.git
cd TVING-Login-Manager-swift

# Requires xcodegen (brew install xcodegen)
xcodegen generate
xcodebuild build -project TvingLoginManager.xcodeproj -scheme TvingLoginManager -configuration Release -destination 'platform=macOS'

# Or create a release zip
./scripts/build-release.sh
```

### Usage

1. Launch app → Click **+** (or `Cmd+N`) to add an account
2. Enter title, TVING ID, password, environment (QC/QA), and plan type
3. Enter OTP code if required
4. Click **Login** → Auto-login proceeds in WebView
   - OTP auto-filled → "Continue" auto-clicked
   - "Login with TVING ID" → **User clicks manually**
   - ID/PW auto-filled → "Login" → **User clicks manually**

### Data Storage

| Item | Location |
|------|----------|
| Account metadata | `~/Library/Application Support/tving-login-manager/accounts.json` |
| Passwords | macOS Keychain (`com.tving.login-manager`) |
| Login URL settings | UserDefaults |

### Tech Stack

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI (Form, List, NavigationSplitView) |
| Browser automation | WKWebView + JavaScript injection |
| Security | Security.framework (Keychain Services) |
| Serialization | Codable + JSONEncoder/Decoder |
| Project generation | XcodeGen |

---

## License

MIT
