#!/bin/bash
# TVAccountManager 스크린샷 자동 생성 스크립트
# macOS 앱용 — screencapture + System Events
#
# 사용법: ./scripts/screenshot.sh [OUTPUT_DIR]

set -euo pipefail

APP_NAME="TVAccountManager"
OUTPUT_DIR="${1:-./screenshots}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"

mkdir -p "$OUTPUT_DIR"

log() { echo "📸 $1"; }

get_window_id() {
    swift -e "
import CoreGraphics
if let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
    for w in windows {
        if let name = w[\"kCGWindowOwnerName\"] as? String, name == \"$APP_NAME\",
           let layer = w[\"kCGWindowLayer\"] as? Int, layer == 0,
           let wid = w[\"kCGWindowNumber\"] as? Int {
            print(wid)
            break
        }
    }
}" 2>/dev/null
}

wait_for_window() {
    local retries=0
    while [ -z "$(get_window_id)" ]; do
        sleep 0.5
        retries=$((retries + 1))
        if [ $retries -ge 20 ]; then
            echo "❌ 윈도우 감지 타임아웃" >&2; exit 1
        fi
    done
}

# --- 외관 모드: System Events ---
ORIGINAL_DARK_MODE=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')

set_appearance() {
    local dark_flag; if [ "$1" = "dark" ]; then dark_flag="true"; else dark_flag="false"; fi
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark_flag"
    sleep 1.0
}

restore_appearance() {
    log "외관 모드 복원 중..."
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $ORIGINAL_DARK_MODE"
}
trap restore_appearance EXIT

# --- UI 조작: 정확한 Accessibility 경로 사용 ---

resize_window() {
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set position of window 1 to {50, 50}
                set size of window 1 to {$1, $2}
            end tell
        end tell
    "
    sleep 0.5
}

click_sidebar_row() {
    local row_num="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set frontmost to true
                delay 0.2
                tell outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1
                    select row $row_num
                end tell
            end tell
        end tell
    "
    sleep 0.5
}

click_toolbar_add() {
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set frontmost to true
                delay 0.2
                -- toolbar의 + 버튼 클릭
                click button 2 of toolbar 1 of window 1
            end tell
        end tell
    "
    sleep 0.5
}

click_account_edit_button() {
    local row_num="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set frontmost to true
                delay 0.2
                -- 계정 row의 Edit(연필) 버튼 = button 1
                click button 1 of UI element 1 of row $row_num of outline 1 of scroll area 1 of group 2 of splitter group 1 of group 1 of window 1
            end tell
        end tell
    "
    sleep 0.5
}

press_escape() {
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                key code 53
            end tell
        end tell
    "
    sleep 0.3
}

capture_window() {
    local filename="$1"
    local filepath="${OUTPUT_DIR}/${filename}.png"
    local wid
    wid=$(get_window_id)
    if [ -n "$wid" ]; then
        screencapture -l "$wid" -o "$filepath"
        log "  ✅ ${filename}.png"
    else
        log "  ❌ 윈도우를 찾을 수 없음"
    fi
}

# --- 메인 ---

log "=== TVAccountManager 스크린샷 자동 생성 ==="
log "출력: $OUTPUT_DIR"
log ""

if ! pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    log "앱 실행 중..."
    open -a "$APP_NAME" 2>/dev/null || open "$(dirname "$0")/../dist/TVAccountManager.app"
else
    log "앱이 이미 실행 중"
fi
wait_for_window
osascript -e "tell application \"$APP_NAME\" to activate"
sleep 0.5

# 윈도우를 넓게 — detail 영역(계정 편집)이 보이도록
resize_window 1200 700
log "윈도우 크기: 1200x700"
log ""

TOTAL=6
COUNT=0

# === 1. Accounts — 라이트 ===
COUNT=$((COUNT + 1)); log "[$COUNT/$TOTAL] Accounts — 라이트 모드"
set_appearance "light"
click_sidebar_row 1
capture_window "01_accounts_light"

# === 2. Accounts — 다크 ===
COUNT=$((COUNT + 1)); log "[$COUNT/$TOTAL] Accounts — 다크 모드"
set_appearance "dark"
capture_window "02_accounts_dark"

# === 3. Account 편집 — 다크 (기존 계정 Edit 버튼 클릭) ===
COUNT=$((COUNT + 1)); log "[$COUNT/$TOTAL] Account 편집 — 다크 모드"
click_account_edit_button 1
sleep 0.5
capture_window "03_account_edit_dark"

# === 4. Account 편집 — 라이트 ===
COUNT=$((COUNT + 1)); log "[$COUNT/$TOTAL] Account 편집 — 라이트 모드"
set_appearance "light"
capture_window "04_account_edit_light"

# === 5. Settings — 라이트 ===
COUNT=$((COUNT + 1)); log "[$COUNT/$TOTAL] Settings — 라이트 모드"
press_escape
click_sidebar_row 2
sleep 0.3
capture_window "05_settings_light"

# === 6. Settings — 다크 ===
COUNT=$((COUNT + 1)); log "[$COUNT/$TOTAL] Settings — 다크 모드"
set_appearance "dark"
capture_window "06_settings_dark"

# 복원
click_sidebar_row 1

log ""
log "=== 완료! ${TOTAL}장 저장됨 ==="
log "📂 $OUTPUT_DIR"
open "$OUTPUT_DIR"
