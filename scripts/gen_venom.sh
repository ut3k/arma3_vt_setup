#!/usr/bin/env bash
set -euo pipefail
BASE_FILE="VT_ARMADA_.html"
TARGET_FILE="VT_VENOM_.html"
NEW_NAME="VT_VENOM_"

echo "=== Generowanie presetu VENOM z $BASE_FILE ==="

if ! command -v pup >/dev/null 2>&1; then
  echo "❌ Brak programu 'pup'. Uruchom przez Dockera lub zainstaluj go ręcznie."
  exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
  echo "❌ Brak programu 'fzf'. Uruchom przez Dockera lub zainstaluj go ręcznie."
  exit 1
fi

bash scripts/gen_template.sh "$BASE_FILE" "$TARGET_FILE" "$NEW_NAME"
