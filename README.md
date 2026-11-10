# TV Account Manager

<p align="center">
  <a href="https://github.com/TvingCorp/TVAccountManager/releases/latest">
    <img src="https://img.shields.io/badge/Download-for%20macOS-0071e3?style=for-the-badge&logo=apple&logoColor=white" alt="Download Latest">
  </a>
</p>

[한국어](#한국어) | [English](#english)

---

## 한국어

TVING QC/QA 환경을 위한 macOS 계정 관리 및 자동 로그인 앱입니다.

### 기능

- **멀티 계정 관리** — 추가 / 수정 / 삭제
- **계정 일괄 등록** — JSON 파일에서 여러 계정을 한번에 불러오기 (중복 자동 건너뜀)
- **계정 내보내기** — 현재 계정 목록을 JSON 파일로 저장 (비밀번호 포함/제외 선택, 저장 후 Finder로 열기)
- **환경 구분** — QC / QA 로그인 URL 분리, 명시적 저장 버튼
- **요금제 태그** — 구독 없음 / 베이직 / 광고 요금제 / 스탠다드 / 프리미엄
- **OTP 자동 입력** — 6자리 코드 자동 분배 입력
- **ID/PW 자동 완성** — React 호환 nativeInputValueSetter 방식
- **프로필 자동 선택** — 로그인 후 프로필이 여러 개면 잠기지 않은 프로필을 자동 선택 (연령 제한 프로필은 후순위). 전부 잠겨 있으면 계정에 저장한 프로필 PIN으로 열고, PIN이 없으면 직접 선택
- **프로필 정보 저장** — 로그인할 때 프로필 목록(이름·잠금·연령)을 자동 수집. 잠금 프로필 PIN은 계정 편집에서 입력 (Keychain 저장)
- **CLI 로그인** — 터미널에서 `tvlogin qa 483920` (창 없는 헤드리스 로그인)
- **비밀번호 보안** — macOS Keychain 저장 (JSON에 평문 미포함)
- **자동 업데이트** — Sparkle 기반 앱 업데이트
- **사용 가이드** — 앱 내 온보딩 가이드 (6페이지)
- **다크/라이트 모드** — 시스템 설정 자동 대응
- **한/영 지원** — 시스템 로케일 자동 대응

### 요구사항

- macOS 14.0 (Sonoma) 이상
- Xcode 15.0 이상 (빌드 시)

### 설치

#### 다운로드
1. [Releases](https://github.com/TvingCorp/TVAccountManager/releases/latest)에서 `TVAccountManager-x.x.x.dmg`를 받습니다 (레포 권한 필요, 없으면 [zip](https://tving-tvaccountmanager.web.app/TVAccountManager.zip)을 받아 압축을 풀고 앱을 `Applications`로 옮깁니다)
2. DMG를 열고, 창 안내대로 `TVAccountManager`를 `Applications` 폴더로 끌어다 놓습니다
3. 이미 설치돼 있으면 "대치"를 누르세요. 계정과 설정은 그대로 유지됩니다

> Apple 공증을 받은 앱이라 추가 설정 없이 바로 실행됩니다. 이후 업데이트는 앱 내 자동 업데이트로 받습니다.

#### 소스에서 빌드
```bash
git clone https://github.com/TvingCorp/TVAccountManager.git
cd TVAccountManager

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
5. 프로필이 여러 개면 잠기지 않은 프로필이 자동 선택됩니다. 잠금 프로필만 있는 계정은 한 번 로그인해 프로필 목록이 채워진 뒤, 계정 편집에서 PIN을 저장하면 다음부터 자동으로 열립니다

### CLI로 로그인

앱 창을 띄우지 않고 터미널에서 바로 로그인합니다. 로그인은 보이지 않는 헤드리스 WebView에서 진행됩니다.

`tvlogin`은 앱 번들 안의 작은 헬퍼 바이너리입니다. 계정 선택기(화살표)는 이 헬퍼가 띄우고, 로그인은 앱 본체가 수행합니다 — 앱 본체는 샌드박스라 터미널을 raw 모드로 바꿀 수 없기 때문입니다.

```bash
./scripts/install-cli.sh      # /usr/local/bin/tvlogin 설치 (권한 없으면 sudo로 재실행)

tvlogin qa                    # QA 계정 목록만 출력
tvlogin qa 483920             # 목록에서 번호를 고른 뒤 로그인
tvlogin qa 483920 --account QA_BASIC
tvlogin prod 483920 --profile 키즈
```

```
  QA 계정 (4)
     1  QA_PREMIUM   webqa7  프리미엄 ★
     2  QA_BASIC     webqa3  베이직
  선택 [1]: 2
  → QA_BASIC
    아이디 입력 중...
    프로필 확인 중...
  [QA] QA_BASIC — 프로필 홍길동 선택 완료
```

| 인자 / 옵션 | 설명 |
|---|---|
| `<env>` | `qc` \| `qa` \| `prod` — `prod`는 QC 계정에 운영 URL (설정은 바뀌지 않음) |
| `<otp>` | TV 화면에 뜬 6자리 숫자. 생략하면 목록만 출력 |
| `--account <title>` | 계정 지정. 생략하면 화살표 선택기 (title 완전일치 → 접두사 → username) |
| `--profile <name>` | 프로필 이름 지정 (기본: 자동 선택) |
| `--no-profile` | 프로필 선택 화면까지만 가고 종료 (확인용) |
| `--json` | 목록과 최종 결과를 JSON으로 출력 (진행 상황은 stderr) |
| `--timeout <sec>` | 로그인 시퀀스 상한, 기본 120 |

종료 코드: `0` 성공 · `1` 로그인 실패 · `2` 인자 오류 / 계정 없음 · `3` 타임아웃 · `4` 프로필이 PIN 잠김인데 저장된 PIN이 없거나 통과 안 됨 (직접 선택 필요) · `130` 취소

> 파이프·스크립트처럼 터미널이 아닌 환경에서 `--account` 없이 실행하면, 프롬프트 앞에서 멈추지 않고 바로 종료합니다.
> `--no-profile`은 확인용입니다. TV 로그인은 프로필을 골라야 완료되므로 정상 로그인 경로가 아닙니다.

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

### 계정 내보내기

현재 계정 목록을 JSON 파일로 저장합니다. 일괄 등록과 같은 형식이라 파일 이름을 `presets.json`으로 바꾸면 그대로 다시 불러올 수 있습니다.

1. 설정 > 일반 > **파일로 계정 내보내기** 클릭
2. **비밀번호 포함** / **비밀번호 제외** 선택
3. 저장 후 Finder가 해당 파일을 선택한 채로 열립니다

파일은 불러오기 폴더에 `accounts-export-2026-09-11-094957.json` 형식으로 저장되며, 초 단위 시각이 붙어 기존 파일을 덮어쓰지 않습니다.

> **비밀번호 포함을 선택하면 파일에 평문으로 저장됩니다.** 공유할 파일이라면 제외를 선택하세요.

### 데이터 저장

| 항목 | 위치 |
|------|------|
| 계정 메타데이터 | `~/Library/Containers/com.tv.account-manager/Data/Library/Application Support/tving-login-manager/accounts.json` |
| 비밀번호 | macOS Keychain (`com.tving.login-manager`) |
| 일괄 등록 파일 | 위 폴더의 `presets.json` (설정 > 일반 > **불러오기 폴더 열기**) |
| 로그인 URL 설정 | UserDefaults |

### 아키텍처

Clean Architecture + TCA-inspired 단방향 Store 패턴

| 레이어 | 역할 |
|--------|------|
| Domain | Repository 프로토콜, UseCase |
| Data | RepositoryImpl (Keychain + JSON) |
| Presentation | State / Action / Reducer, Store |
| Views | SwiftUI (3-column NavigationSplitView) |
| CLI | Headless login entry point + picker helper (`tvlogin`) |
| CLI | 헤드리스 로그인 진입점 + 선택기 헬퍼 (`tvlogin`) |

### 기술 스택

| 구분 | 기술 |
|------|------|
| UI | SwiftUI (Form, List, NavigationSplitView) |
| 상태 관리 | TCA-inspired 단방향 Store |
| 브라우저 자동화 | WKWebView + JavaScript injection |
| 보안 | Security.framework (Keychain Services) |
| 자동 업데이트 | Sparkle (EdDSA 서명) |
| CLI UI | Noora (Tuist) — 화살표 선택기 |
| 테스트 | Swift Testing (143 tests) |
| 프로젝트 생성 | XcodeGen |

---

## English

A macOS account management and auto-login app for TVING QC/QA environments.

### Features

- **Multi-account management** — Add / Edit / Delete
- **Bulk import** — Import multiple accounts from a JSON file (duplicates auto-skipped)
- **Export** — Save the account list to a JSON file (choose whether to include passwords, revealed in Finder when done)
- **Environment separation** — QC / QA login URLs with explicit save
- **Plan tags** — None / Basic / Ad-supported / Standard / Premium
- **OTP auto-fill** — Distributes 6 digits across individual input fields
- **ID/PW auto-fill** — React-compatible nativeInputValueSetter
- **Automatic profile selection** — Picks an unlocked profile after login when the account has several (age-restricted profiles come last). If every profile is locked, it opens one with the profile PIN saved for the account; without a PIN you pick one yourself
- **Profile info** — The profile list (name, lock, age setting) is collected on login. PINs for locked profiles are entered in the account editor (stored in Keychain)
- **CLI login** — `tvlogin qa 483920` from the terminal (headless, no window)
- **Password security** — Stored in macOS Keychain (not in JSON)
- **Auto-update** — Sparkle-based app updates
- **Usage guide** — Built-in onboarding guide (6 pages)
- **Dark/Light mode** — Follows system appearance
- **Localization** — English and Korean (follows system locale)

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)

### Installation

#### Download
1. Download `TVAccountManager-x.x.x.dmg` from [Releases](https://github.com/TvingCorp/TVAccountManager/releases/latest) (needs repository access; otherwise download the [zip](https://tving-tvaccountmanager.web.app/TVAccountManager.zip), extract it and move the app to `Applications`)
2. Open the DMG and drag `TVAccountManager` to the `Applications` folder as shown
3. If it is already installed, choose "Replace". Your accounts and settings are kept

> The app is notarized by Apple, so it opens without extra steps. Later updates arrive through in-app auto-update.

#### Build from Source
```bash
git clone https://github.com/TvingCorp/TVAccountManager.git
cd TVAccountManager

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
5. If the account has several profiles, an unlocked one is selected automatically. For an account with only locked profiles, log in once so the profile list fills in, then save a PIN in the account editor

### CLI Login

Log in from the terminal without opening the app window. The login runs in a hidden headless WebView.

`tvlogin` is a small helper binary inside the app bundle. It renders the arrow-key account picker; the app binary itself performs the login. The split exists because the sandboxed app cannot put the terminal into raw mode.

```bash
./scripts/install-cli.sh      # installs /usr/local/bin/tvlogin (re-run with sudo if needed)

tvlogin qa                    # list QA accounts only
tvlogin qa 483920             # pick an account by number, then log in
tvlogin qa 483920 --account QA_BASIC
tvlogin prod 483920 --profile Kids
```

| Argument / Option | Description |
|---|---|
| `<env>` | `qc` \| `qa` \| `prod` — `prod` uses QC accounts with the production URL (settings untouched) |
| `<otp>` | The 6-digit code shown on the TV. Omit it to only list accounts |
| `--account <title>` | Pick an account without the picker (exact title → prefix → username) |
| `--profile <name>` | Pick a profile by name (default: automatic) |
| `--no-profile` | Stop at the profile screen without selecting |
| `--json` | Emit the list and the final result as JSON (progress stays on stderr) |
| `--timeout <sec>` | Login sequence limit, default 120 |

Exit codes: `0` success · `1` login failed · `2` bad arguments / no account · `3` timeout · `4` profile is PIN-locked and no saved PIN worked (pick one yourself) · `130` cancelled

> When stdin is not a terminal (pipes, scripts) and `--account` is absent, it exits immediately instead of waiting at the prompt.
> `--no-profile` is for inspection only — TV login completes only once a profile is selected.

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

### Export

Saves the current account list to a JSON file. It uses the same format as bulk import, so renaming the file to `presets.json` imports it straight back.

1. Settings > General > **Export Accounts to File**
2. Choose **Include Passwords** or **Exclude Passwords**
3. Finder opens with the saved file selected

The file lands in the import folder as `accounts-export-2026-09-11-094957.json`; the second-precision timestamp keeps repeated exports from overwriting each other.

> **Including passwords writes them to the file as plain text.** Exclude them for any file you intend to share.

### Data Storage

| Item | Location |
|------|----------|
| Account metadata | `~/Library/Containers/com.tv.account-manager/Data/Library/Application Support/tving-login-manager/accounts.json` |
| Passwords | macOS Keychain (`com.tving.login-manager`) |
| Bulk import file | `presets.json` in the folder above (Settings > General > **Open Import Folder**) |
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
| CLI UI | Noora (Tuist) — arrow-key picker |
| Testing | Swift Testing (143 tests) |
| Project generation | XcodeGen |

---

## License

MIT
