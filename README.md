# TV Account Manager

[![Download Latest](https://img.shields.io/github/v/release/doyeonk35/Account-Manager-swift?label=Download%20for%20macOS&style=for-the-badge&logo=apple&logoColor=white&color=0071e3)](https://github.com/doyeonk35/Account-Manager-swift/releases/latest)

[한국어](#한국어) | [English](#english)

---

## 한국어

TVING QC/QA 환경을 위한 macOS 계정 관리 및 자동 로그인 앱입니다.

### 기능

- **멀티 계정 관리** — 추가 / 수정 / 삭제
- **계정 일괄 등록** — JSON 파일에서 여러 계정을 한번에 불러오기 (중복 자동 건너뜀)
- **환경 구분** — QC / QA 로그인 URL 분리, 명시적 저장 버튼
- **요금제 태그** — 구독 없음 / 베이직 / 광고 요금제 / 스탠다드 / 프리미엄
- **OTP 자동 입력** — 6자리 코드 자동 분배 입력
- **ID/PW 자동 완성** — React 호환 nativeInputValueSetter 방식
- **비밀번호 보안** — macOS Keychain 저장 (JSON에 평문 미포함)
- **자동 업데이트** — Sparkle 기반 앱 업데이트
- **사용 가이드** — 앱 내 온보딩 가이드 (6페이지)
- **다크/라이트 모드** — 시스템 설정 자동 대응
- **한/영 지원** — 시스템 로케일 자동 대응

### 요구사항

- macOS 14.0 (Sonoma) 이상
- Xcode 15.0 이상 (빌드 시)

### 설치

#### GitHub Releases
1. [Releases](https://github.com/doyeonk35/Account-Manager-swift/releases) 페이지에서 최신 `TVAccountManager-x.x.x.zip` 다운로드
2. 압축 해제 후 `TVAccountManager.app`을 `/Applications`로 이동
3. 최초 실행 전 터미널에서 quarantine 플래그 제거:
```bash
xattr -cr /Applications/TVAccountManager.app
```
> 서명되지 않은 앱이므로 이 과정이 필요합니다. 이후 업데이트는 앱 내 자동 업데이트로 받을 수 있습니다.

#### 소스에서 빌드
```bash
git clone https://github.com/doyeonk35/Account-Manager-swift.git
cd Account-Manager-swift

# Info.plist 생성 (환경 URL 설정)
./scripts/setup-plist.sh

# xcodegen 필요 (brew install xcodegen)
xcodegen generate
xcodebuild build -scheme TVAccountManager -configuration Release -destination 'platform=macOS'
```

### 사용 방법

1. 앱 실행 → **+** 버튼 (또는 `Cmd+N`)으로 계정 추가
2. 타이틀, TVING ID, 비밀번호, 환경(QC/QA), 요금제 선택 후 저장
3. OTP 코드 입력 (필요 시)
4. **Login** 버튼 클릭 → WebView에서 자동 로그인 진행

### 계정 일괄 등록

여러 계정을 한번에 등록할 수 있습니다.

1. 설정 > 일반 > **불러오기 폴더 열기** 클릭
2. 폴더에 생성된 `presets.example.json`을 참고하여 `presets.json` 작성
3. **파일에서 계정 불러오기** 클릭

```json
[
  {
    "title": "QA 베이직",
    "username": "your_id",
    "password": "your_password",
    "account_type": "QA",
    "plan_type": "베이직",
    "memo": ""
  }
]
```

> `account_type`: `QC` | `QA`
> `plan_type`: `구독 없음` | `베이직` | `광고 요금제` | `스탠다드` | `프리미엄`

### 데이터 저장

| 항목 | 위치 |
|------|------|
| 계정 메타데이터 | `~/Library/Application Support/tving-login-manager/accounts.json` |
| 비밀번호 | macOS Keychain (`com.tving.login-manager`) |
| 일괄 등록 파일 | `~/Library/Application Support/tving-login-manager/presets.json` |
| 로그인 URL 설정 | UserDefaults |

### 아키텍처

Clean Architecture + TCA-inspired 단방향 Store 패턴

| 레이어 | 역할 |
|--------|------|
| Domain | Repository 프로토콜, UseCase |
| Data | RepositoryImpl (Keychain + JSON) |
| Presentation | State / Action / Reducer, Store |
| Views | SwiftUI (3-column NavigationSplitView) |

### 기술 스택

| 구분 | 기술 |
|------|------|
| UI | SwiftUI (Form, List, NavigationSplitView) |
| 상태 관리 | TCA-inspired 단방향 Store |
| 브라우저 자동화 | WKWebView + JavaScript injection |
| 보안 | Security.framework (Keychain Services) |
| 자동 업데이트 | Sparkle (EdDSA 서명) |
| 테스트 | Swift Testing (91 tests) |
| 프로젝트 생성 | XcodeGen |

---

## English

A macOS account management and auto-login app for TVING QC/QA environments.

### Features

- **Multi-account management** — Add / Edit / Delete
- **Bulk import** — Import multiple accounts from a JSON file (duplicates auto-skipped)
- **Environment separation** — QC / QA login URLs with explicit save
- **Plan tags** — None / Basic / Ad-supported / Standard / Premium
- **OTP auto-fill** — Distributes 6 digits across individual input fields
- **ID/PW auto-fill** — React-compatible nativeInputValueSetter
- **Password security** — Stored in macOS Keychain (not in JSON)
- **Auto-update** — Sparkle-based app updates
- **Usage guide** — Built-in onboarding guide (6 pages)
- **Dark/Light mode** — Follows system appearance
- **Localization** — English and Korean (follows system locale)

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)

### Installation

#### GitHub Releases
1. Download the latest `TVAccountManager-x.x.x.zip` from the [Releases](https://github.com/doyeonk35/Account-Manager-swift/releases) page
2. Extract and move `TVAccountManager.app` to `/Applications`
3. Remove quarantine flag before first launch:
```bash
xattr -cr /Applications/TVAccountManager.app
```
> Required because the app is not code-signed with a Developer ID. Subsequent updates are delivered via in-app auto-update.

#### Build from Source
```bash
git clone https://github.com/doyeonk35/Account-Manager-swift.git
cd Account-Manager-swift

# Generate Info.plist (sets environment URLs)
./scripts/setup-plist.sh

# Requires xcodegen (brew install xcodegen)
xcodegen generate
xcodebuild build -scheme TVAccountManager -configuration Release -destination 'platform=macOS'
```

### Usage

1. Launch app → Click **+** (or `Cmd+N`) to add an account
2. Enter title, TVING ID, password, environment (QC/QA), and plan type
3. Enter OTP code if required
4. Click **Login** → Auto-login proceeds in WebView

### Bulk Import

Import multiple accounts at once from a JSON file.

1. Go to Settings > General > Click **Open Import Folder**
2. Use the generated `presets.example.json` as a template to create `presets.json`
3. Click **Import Accounts from File**

```json
[
  {
    "title": "QA Basic",
    "username": "your_id",
    "password": "your_password",
    "account_type": "QA",
    "plan_type": "베이직",
    "memo": ""
  }
]
```

> `account_type`: `QC` | `QA`
> `plan_type`: `구독 없음` | `베이직` | `광고 요금제` | `스탠다드` | `프리미엄`

### Data Storage

| Item | Location |
|------|----------|
| Account metadata | `~/Library/Application Support/tving-login-manager/accounts.json` |
| Passwords | macOS Keychain (`com.tving.login-manager`) |
| Bulk import file | `~/Library/Application Support/tving-login-manager/presets.json` |
| Login URL settings | UserDefaults |

### Architecture

Clean Architecture + TCA-inspired unidirectional Store pattern

| Layer | Role |
|-------|------|
| Domain | Repository protocols, UseCases |
| Data | RepositoryImpl (Keychain + JSON) |
| Presentation | State / Action / Reducer, Store |
| Views | SwiftUI (3-column NavigationSplitView) |

### Tech Stack

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI (Form, List, NavigationSplitView) |
| State management | TCA-inspired unidirectional Store |
| Browser automation | WKWebView + JavaScript injection |
| Security | Security.framework (Keychain Services) |
| Auto-update | Sparkle (EdDSA signing) |
| Testing | Swift Testing (91 tests) |
| Project generation | XcodeGen |

---

## License

MIT
