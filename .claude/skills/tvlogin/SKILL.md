---
name: tvlogin
description: Use when logging a TV device into a TVING QC/QA account from the terminal — "qa 483920으로 로그인", "QC 계정으로 TV 로그인해줘", "tvlogin", "티빙 계정 로그인". Needs the 6-digit pairing code shown on the TV screen.
---

# tvlogin — TV 페어링 자동 로그인

TV 화면의 6자리 페어링 코드로 TVING 계정에 로그인한다. 창은 뜨지 않는다(헤드리스).

## 호출 방법

두 단계로 호출한다. 목록을 먼저 받고, 계정을 title로 지정해 실행한다.

```bash
tvlogin <env> --json                                  # 1. 계정 목록
tvlogin <env> <otp> --account "<title>" --json        # 2. 로그인
```

`<env>` = `qc` | `qa` | `prod` (prod는 QC 계정 + 운영 URL, 앱 설정은 바뀌지 않는다)

## 규칙

**OTP는 코드가 떠 있는 화면에서 가져온다.** 6자리이고 매번 바뀐다. 추측하거나 예시 값을
쓰지 말 것. 코드를 보여주는 쪽은 TV(기기) 화면이지, 이 CLI가 자동화하는 페어링 페이지가 아니다.

- **직접 읽을 수 있는 경우** — devicehub 시뮬레이터, Chrome·ego-lite 등 브라우저로 띄운 웹 TV처럼
  화면에 접근할 수 있으면 스크린샷이나 DOM에서 직접 읽는다. 사용자에게 묻지 말 것.
- **물어봐야 하는 경우** — 실물 TV 등 화면에 접근할 수 없을 때.

코드는 금방 만료되므로 읽은 직후 바로 로그인을 실행한다. 재시도할 때는 **이전 코드를 다시 쓰지
말고** 화면에서 새 코드를 다시 읽는다.

**계정은 반드시 `--account`로 지정한다.** 비대화형에서 생략하면 프롬프트 대기 없이 exit 2로
끝난다(설계된 동작). 번호가 아니라 title로 지정해야 계정이 추가돼도 안 깨진다.
`--account`는 title 완전일치 → title 접두사 → username 순으로 찾고, 후보가 여럿이면
목록을 출력하고 멈춘다.

**`message` 문자열을 파싱하지 말 것.** 시스템 언어에 따라 바뀐다. 분기는 exit 코드로 한다.

## 종료 코드

| 코드 | 의미 | 할 일 |
|---|---|---|
| 0 | 로그인 완료 | 결과의 `profile`과 함께 보고 |
| 1 | 로그인 실패 (폼 못 찾음·자격증명 거부) | stderr 진행 로그를 첨부해 보고 |
| 2 | 인자 오류 / 계정 없음 / 키체인에 비밀번호 없음 | 출력된 후보로 `--account`를 정정해 재시도 |
| 3 | 타임아웃 | `--timeout`을 늘려 재시도하거나 보고 |
| 4 | 프로필이 전부 PIN 잠김 | **로그인 미완료.** 앱 GUI나 TV에서 사람이 직접 프로필을 골라야 한다고 안내 |
| 130 | 사용자 취소 | 그대로 종료 |

## 출력

- 계정 목록·최종 결과(JSON) → **stdout**
- 진행 상황 → **stderr** (실패 보고 시 같이 전달)

```json
{"env":"qa","accounts":[{"title":"...","username":"...","plan":"베이직","pinned":false,"hasPassword":true}]}
{"ok":true,"env":"qa","account":"...","profile":"...","exit":0,"message":"..."}
```

`hasPassword`가 false면 키체인에 비밀번호가 없는 계정이다 — 고르지 말고 사용자에게 알린다.

## 옵션

`--profile <name>` 프로필 이름 지정 · `--no-profile` 프로필 화면까지만(확인용, 정상 로그인
경로 아님) · `--timeout <sec>` 기본 120

## 설치가 안 돼 있을 때

`tvlogin: command not found`면 앱이 설치됐는지 확인하고 `./scripts/install-cli.sh`를 실행하게
안내한다. 앱(1.4.0 이상)이 `/Applications`에 있어야 한다.
