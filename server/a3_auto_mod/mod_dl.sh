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

# Zmienne obliczane muszą znajdować się w skrypcie, a nie w .env.
MOD_STORAGE_DIR="${MOD_STORAGE_DIR:-.storage}"
PORTABLE_WORKSHOP_DIR="$TARGET_DIR/$MOD_STORAGE_DIR/workshop/content/$APP_ID"

READY_FILE="$TARGET_DIR/.mods-ready"
READY_FILE_TMP="${READY_FILE}.tmp"

# Compose przekazuje STEAM_LOGIN, ale ten fallback umożliwia również
# bezpośrednie uruchomienie skryptu z wartością STEAM_ACCOUNT.
STEAM_LOGIN="${STEAM_LOGIN:-${STEAM_ACCOUNT:-}}"

: "${STEAM_LOGIN:?Brak STEAM_LOGIN lub STEAM_ACCOUNT}"
: "${STEAM_PASSWORD:?Brak STEAM_PASSWORD}"

mkdir -p "$TARGET_DIR" "$PORTABLE_WORKSHOP_DIR"

# Brak markera oznacza synchronizację w toku albo błąd.
rm -f -- "$READY_FILE" "$READY_FILE_TMP"

if ! command -v "$STEAMCMD" >/dev/null 2>&1; then
  echo "Nie znaleziono SteamCMD: $STEAMCMD" >&2
  exit 1
fi

clean_steam_cache() {
  local steam_root="/root/Steam"
  echo "=== Oczyszczanie pamięci podręcznej i logów SteamCMD ==="
  
  if [[ -d "$steam_root/steamapps/workshop/downloads" ]]; then
    find "$steam_root/steamapps/workshop/downloads" -mindepth 1 -delete 2>/dev/null || true
  fi
  if [[ -d "$steam_root/steamapps/downloading" ]]; then
    find "$steam_root/steamapps/downloading" -mindepth 1 -delete 2>/dev/null || true
  fi
  if [[ -d "$steam_root/steamapps/temp" ]]; then
    find "$steam_root/steamapps/temp" -mindepth 1 -delete 2>/dev/null || true
  fi
  if [[ -d "$steam_root/logs" ]]; then
    find "$steam_root/logs" -mindepth 1 -delete 2>/dev/null || true
  fi
}

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

download_all() {
  local attempt=1
  local max_attempts=3
  local id
  local -a steamcmd_args

  while (( attempt <= max_attempts )); do
    echo "Pobieranie ${#MOD_IDS[@]} modów, próba $attempt/$max_attempts"

    steamcmd_args=(+login "$STEAM_LOGIN" "$STEAM_PASSWORD")

    for id in "${MOD_IDS[@]}"; do
      steamcmd_args+=(+workshop_download_item "$APP_ID" "$id" validate)
    done

    steamcmd_args+=(+quit)

    if "$STEAMCMD" "${steamcmd_args[@]}"; then
      return 0
    fi

    echo "Błąd pobierania modów, ponawiam..."
    ((attempt++))
    sleep 5
  done

  echo "Nie udało się pobrać modów po $max_attempts próbach" >&2
  return 1
}

create_lower_symlinks() {
  local dir
  local file
  local rel_path
  local lower_path
  local lower_file
  local link_path
  local portable_source
  local relative_source

  mkdir -p "$TARGET_DIR" "$PORTABLE_WORKSHOP_DIR"

  # Usuń stary widok, ale zachowaj prawdziwe dane w .storage.
  find "$TARGET_DIR" \
    -mindepth 1 \
    -maxdepth 1 \
    ! -name "$MOD_STORAGE_DIR" \
    -exec rm -rf -- {} +

  while IFS= read -r -d '' dir; do
    rel_path="${dir#$WORKSHOP_DIR/}"
    lower_path="$(printf '%s' "$rel_path" | tr '[:upper:]' '[:lower:]')"

    mkdir -p "$TARGET_DIR/$lower_path"
  done < <(
    find "$WORKSHOP_DIR" \
      -mindepth 1 \
      -type d \
      -print0
  )

  while IFS= read -r -d '' file; do
    rel_path="${file#$WORKSHOP_DIR/}"
    lower_file="$(printf '%s' "$rel_path" | tr '[:upper:]' '[:lower:]')"

    link_path="$TARGET_DIR/$lower_file"
    portable_source="$PORTABLE_WORKSHOP_DIR/$rel_path"

    mkdir -p "$(dirname "$link_path")"

    if [[ -e "$link_path" || -L "$link_path" ]]; then
      echo "Kolizja ścieżki lowercase: $lower_file" >&2
      return 1
    fi

    # Symlink względny — działa po podpięciu wolumenu do innej usługi.
    relative_source="$(
      realpath \
        --relative-to="$(dirname "$link_path")" \
        "$portable_source"
    )"

    ln -s "$relative_source" "$link_path"
  done < <(
    find "$WORKSHOP_DIR" \
      -type f \
      -print0
  )
}

validate_lower_symlinks() {
  local broken_link
  local source_count
  local target_count

  broken_link="$(
    find "$TARGET_DIR" \
      -path "$TARGET_DIR/$MOD_STORAGE_DIR" -prune -o \
      -type l \
      ! -exec test -e {} \; \
      -print \
      -quit
  )"

  if [[ -n "$broken_link" ]]; then
    echo "Niedziałający symlink: $broken_link" >&2
    return 1
  fi

  source_count="$(
    find "$WORKSHOP_DIR" \
      -type f \
      -printf '.' \
      | wc -c
  )"

  target_count="$(
    find "$TARGET_DIR" \
      -path "$TARGET_DIR/$MOD_STORAGE_DIR" -prune -o \
      -type l \
      -printf '.' \
      | wc -c
  )"

  if (( source_count == 0 )); then
    echo "Magazyn nie zawiera plików modów" >&2
    return 1
  fi

  if (( source_count != target_count )); then
    echo "Liczba plików i symlinków jest różna" >&2
    echo "Źródła: $source_count, symlinki: $target_count" >&2
    return 1
  fi

  echo "Walidacja symlinków zakończona pomyślnie"
}

clean_steam_cache

echo "oczyszczam nie używane mody"
cleanup_stale_mods
echo "oczyszczanie zakończone"

echo "Rozpoczynam pobieranie modów"
download_all

echo "Pobieranie zakończone"

echo "Generuję symlinki lowercase"
create_lower_symlinks

echo "Waliduję symlinki"
validate_lower_symlinks

clean_steam_cache

printf 'ready\n' > "$READY_FILE_TMP"
mv -f -- "$READY_FILE_TMP" "$READY_FILE"

echo "Symlinki lowercase gotowe"
echo "MODY gotowe"
