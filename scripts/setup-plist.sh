#!/bin/bash
# Generate Info.plist from template with actual environment URLs.
# Run this after cloning the repo.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$PROJECT_DIR/TVAccountManager/Info.plist.template"
OUTPUT="$PROJECT_DIR/TVAccountManager/Info.plist"

if [ ! -f "$TEMPLATE" ]; then
    echo "Error: Info.plist.template not found at $TEMPLATE"
    exit 1
fi

QC_URL="${DEFAULT_QC_LOGIN_URL:-https://user.tving.com/}"
QA_URL="${DEFAULT_QA_LOGIN_URL:-https://userqa.tving.com/tv/login/qrcode.tving}"

sed -e "s|__DEFAULT_QC_LOGIN_URL__|$QC_URL|g" \
    -e "s|__DEFAULT_QA_LOGIN_URL__|$QA_URL|g" \
    "$TEMPLATE" > "$OUTPUT"

echo "Generated Info.plist with environment URLs."
