#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="$1"
TARGET_FILE="$2"
NEW_PRESET_NAME="$3"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "Brak pliku źródłowego: $SOURCE_FILE"
  exit 1
fi

if ! command -v pup >/dev/null 2>&1; then
  echo "Brak narzędzia 'pup'. Uruchom przez Dockera lub zainstaluj lokalnie."
  exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
  echo "Brak narzędzia 'fzf'. Uruchom przez Dockera lub zainstaluj lokalnie."
  exit 1
fi

# 1. Pobierz listę modów
mapfile -t mods < <(pup 'td[data-type="DisplayName"] text{}' <"$SOURCE_FILE")
if [ ${#mods[@]} -eq 0 ]; then
  echo "Nie znaleziono modów w pliku."
  exit 1
fi

# 2. Wybór modów do usunięcia
echo "Wybierz mody do usunięcia (spacja = zaznacz, Enter = zatwierdź, / = filtr):"
mapfile -t to_remove < <(printf "%s\n" "${mods[@]}" |
  fzf --multi --bind 'space:toggle,ctrl-a:select-all,ctrl-d:deselect-all' \
    --reverse --height=90% --border --prompt="Usuń: ")

if [ ${#to_remove[@]} -eq 0 ]; then
  echo "Nie wybrano żadnych modów. Anulowano."
  exit 0
fi

clear
echo "Wybrane do usunięcia:"
for m in "${to_remove[@]}"; do echo " - $m"; done
echo
read -rp "Na pewno usunąć te mody? (y/N): " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && {
  echo "Anulowano."
  exit 0
}

# 3. Utwórz kopię docelową
cp "$SOURCE_FILE" "$TARGET_FILE"

# 4. Usuń wybrane mody (całe <tr> sekcje)
for mod in "${to_remove[@]}"; do
  echo "Usuwam: $mod"
  tmp=$(mktemp)
  awk -v pat="$mod" '
    BEGIN { IGNORECASE=1; skip=0 }
    /<tr data-type="ModContainer">/ { buf=$0; in_tr=1; next }
    /<\/tr>/ {
      if (in_tr) {
        buf=buf"\n"$0
        if (buf ~ pat) {
          in_tr=0; next
        } else {
          print buf
          in_tr=0; next
        }
      }
    }
    in_tr { buf=buf"\n"$0; next }
    { print }
  ' "$TARGET_FILE" >"$tmp"
  mv "$tmp" "$TARGET_FILE"
done

# 5. Aktualizacja nazwy presetu
sed -i -E "s|(<meta name=\"arma:PresetName\" content=\")[^\"]*(\" */>)|\1${NEW_PRESET_NAME}\2|" "$TARGET_FILE"
sed -i -E "s|(<h1>Arma 3[[:space:]]*- Preset <strong>)[^<]*(</strong>)|\1${NEW_PRESET_NAME}\2|" "$TARGET_FILE"

echo "Nowy preset zapisany jako: $TARGET_FILE"
