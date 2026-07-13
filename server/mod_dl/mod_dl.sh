#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

STEAMCMD="${STEAMCMD:-steamcmd}"
APP_ID="${APP_ID:-107410}"
PRESET_DIR="${PRESET_DIR:-/data/preset}"
WORKSHOP_DIR="${WORKSHOP_DIR:-/root/Steam/steamapps/workshop/content/${APP_ID}}"
TARGET_DIR="${TARGET_DIR:-/arma3/servermods}"

# Wczytaj .env, jeśli istnieje lokalnie
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${STEAM_LOGIN:?Brak STEAM_LOGIN w pliku .env}"

if ! command -v "$STEAMCMD" >/dev/null 2>&1; then
  echo "Nie znaleziono SteamCMD: $STEAMCMD" >&2
  exit 1
fi

resolve_preset() {
  local preset_arg="${1:-}"

  if [[ -n "$preset_arg" ]]; then
    if [[ -f "$preset_arg" ]]; then
      printf '%s\n' "$preset_arg"
      return 0
    fi

    if [[ -f "$PRESET_DIR/$preset_arg" ]]; then
      printf '%s\n' "$PRESET_DIR/$preset_arg"
      return 0
    fi

    echo "Nie znaleziono pliku presetu: $preset_arg" >&2
    exit 1
  fi

  local latest
  latest="$(
    find "$PRESET_DIR" -maxdepth 1 -type f -name '*.html' -printf '%T@ %p\n' 2>/dev/null \
      | sort -nr \
      | awk 'NR==1 {sub(/^[0-9.]+ /, ""); print}'
  )"

  if [[ -z "$latest" ]]; then
    echo "Brak plików .html w katalogu: $PRESET_DIR" >&2
    exit 1
  fi

  printf '%s\n' "$latest"
}

PRESET_FILE="$(resolve_preset "${1:-}")"
echo "Używam presetu: $PRESET_FILE"

mapfile -t MOD_IDS < <(
  grep -oE 'https://steamcommunity\.com/sharedfiles/filedetails/\?id=[0-9]+' "$PRESET_FILE" \
    | sed -E 's/.*id=([0-9]+)/\1/' \
    | awk '!seen[$0]++' || true
)

if (( ${#MOD_IDS[@]} == 0 )); then
  echo "Nie znaleziono żadnych ID modów w: $PRESET_FILE" >&2
  exit 1
fi

cleanup_stale_mods() {
  declare -A keep=()
  local id dir name

  for id in "${MOD_IDS[@]}"; do
    keep["$id"]=1
  done

  mkdir -p "$WORKSHOP_DIR"

  while IFS= read -r -d '' dir; do
    name="${dir##*/}"
    if [[ -z "${keep[$name]+x}" ]]; then
      echo "Usuwam nieużywany mod: $name"
      rm -rf -- "$dir"
    fi
  done < <(find "$WORKSHOP_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
}

download_one() {
  local id="${1:?Brak ID moda}"
  local attempt=1
  local max_attempts=3

  while (( attempt <= max_attempts )); do
    echo "Pobieranie moda $id, próba $attempt/$max_attempts"

    if "$STEAMCMD" \
      +login "$STEAM_LOGIN" "$STEAM_PASSWORD" \
      +workshop_download_item "$APP_ID" "$id" validate \
      +quit; then
      return 0
    fi

    echo "Błąd pobierania moda $id, ponawiam..."
    ((attempt++))
    sleep 5
  done

  echo "Nie udało się pobrać moda $id po $max_attempts próbach" >&2
  return 1
}

create_lower_symlinks() {
    mkdir -p "$TARGET_DIR"
    find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

  while IFS= read -r -d '' dir; do
    rel_path="${dir#$WORKSHOP_DIR/}"
    lower_path="$(printf '%s' "$rel_path" | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$(dirname "$TARGET_DIR/$lower_path")"
  done < <(find "$WORKSHOP_DIR" -mindepth 1 -type d -print0)

  while IFS= read -r -d '' file; do
    rel_path="${file#$WORKSHOP_DIR/}"
    lower_file="$(printf '%s' "$rel_path" | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$(dirname "$TARGET_DIR/$lower_file")"
    if [[ ! -L "$TARGET_DIR/$lower_file" ]]; then
      ln -s "$file" "$TARGET_DIR/$lower_file"
    fi
  done < <(find "$WORKSHOP_DIR" -type f -print0)
}

echo "oczyszczam nie używane mody"
cleanup_stale_mods
echo "oczyszczanie zakończone"


echo "Rozpoczynam pobieranie modów"
for id in "${MOD_IDS[@]}"; do
  download_one "$id"
done

echo "Pobieranie zakończone"
echo "Generuje symlinki"
create_lower_symlinks
echo "Symlinki LOWER CASE gotowe"

echo "MODY Gotowe"
