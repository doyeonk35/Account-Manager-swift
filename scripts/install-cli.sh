#!/bin/sh
# tvlogin 설치 — 앱 바이너리를 호출하는 한 줄 래퍼를 PATH에 놓는다.
#
# 사용법:
#   ./scripts/install-cli.sh [앱 경로]
#   TVLOGIN_DEST=~/bin/tvlogin ./scripts/install-cli.sh
#
# 심볼릭 링크 대신 래퍼를 쓰는 이유: 링크로 실행하면 Bundle.main이 앱 번들을 못 찾아
# Info.plist의 기본 로그인 URL(DefaultQCLoginURL)을 읽지 못한다.
set -e

APP="${1:-/Applications/TVAccountManager.app}"
# 선택기 UI를 띄우는 tvlogin 헬퍼를 가리킨다. 헬퍼가 나머지 인자를 앱 바이너리로 넘긴다.
# (앱 본체는 샌드박스라 터미널 raw 모드를 못 쓴다 — tcsetattr가 EPERM)
BIN="$APP/Contents/MacOS/tvlogin"
DEST="${TVLOGIN_DEST:-/usr/local/bin/tvlogin}"
DEST_DIR=$(dirname "$DEST")

if [ ! -x "$BIN" ]; then
    echo "앱 실행 파일을 찾을 수 없습니다: $BIN" >&2
    echo "앱 경로를 인자로 넘기세요: $0 /path/to/TVAccountManager.app" >&2
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    echo "대상 디렉터리가 없습니다: $DEST_DIR" >&2
    exit 1
fi

if [ ! -w "$DEST_DIR" ]; then
    echo "$DEST_DIR 에 쓸 권한이 없습니다. sudo로 다시 실행하세요:" >&2
    echo "  sudo $0 $APP" >&2
    exit 1
fi

TMP=$(mktemp)
cat > "$TMP" <<EOF
#!/bin/sh
# TV Account Manager CLI 래퍼 — scripts/install-cli.sh 가 생성했습니다.
[ \$# -eq 0 ] && set -- --help
exec "$BIN" "\$@"
EOF

install -m 755 "$TMP" "$DEST"
rm -f "$TMP"

echo "설치 완료: $DEST -> $BIN"
"$DEST" --version
