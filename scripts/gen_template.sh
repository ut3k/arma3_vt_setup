#!/usr/bin/env bash
#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="$1"
TARGET_FILE="$2"
NEW_PRESET_NAME="$3"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "❌ Brak pliku źródłowego: $SOURCE_FILE"
  exit 1
fi

if ! command -v pup >/dev/null 2>&1; then
  echo "❌ Brak narzędzia 'pup'. Uruchom przez Dockera lub zainstaluj lokalnie."
  exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
  echo "❌ Brak narzędzia 'fzf'. Uruchom przez Dockera lub zainstaluj lokalnie."
  exit 1
fi

# === 1. Wczytaj listę modów przez pup ===
mapfile -t mods < <(pup 'td[data-type="DisplayName"] text{}' <"$SOURCE_FILE")
if [ ${#mods[@]} -eq 0 ]; then
  echo "❌ Nie znaleziono modów w pliku!"
  exit 1
fi

# === 2. Interaktywny wybór do usunięcia ===
echo "📦 Wybierz mody do USUNIĘCIA (spacja = zaznacz, Enter = zatwierdź, / = filtr):"
mapfile -t to_remove < <(printf "%s\n" "${mods[@]}" |
  fzf --multi --bind 'space:toggle,ctrl-a:select-all,ctrl-d:deselect-all' \
    --reverse --height=90% --border --prompt="Usuń: ")

if [ ${#to_remove[@]} -eq 0 ]; then
  echo "🚫 Nie wybrano żadnych modów. Anulowano."
  exit 0
fi

clear
echo "🔎 Wybrane do usunięcia:"
for m in "${to_remove[@]}"; do echo " - $m"; done
echo
read -rp "Na pewno usunąć te mody? (y/N): " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && {
  echo "❎ Anulowano."
  exit 0
}

cp "$SOURCE_FILE" "$TARGET_FILE"

# === 3. Usuń wybrane mody z drzewa HTML ===
# Zrobimy to w czystym bashu + pup:
for mod in "${to_remove[@]}"; do
  echo "🧹 Usuwam: $mod"
  # znajdź wiersz <tr> zawierający ten mod i usuń go całkowicie
  tmp=$(mktemp)
  # przefiltruj całą zawartość .mod-list i usuń odpowiednie tr
  pup 'div.mod-list table tr' <"$TARGET_FILE" |
    grep -F -v "$mod" >"$tmp"

  # teraz odbuduj oryginalny plik: zamień sekcję <div class="mod-list"> ... </div>
  awk -v block="$(cat "$tmp")" '
    /<div class="mod-list">/ {
      print; print "      <table>"; print block; print "      </table>";
      in_block = 1; next
    }
    in_block && /<\/div>/ { in_block = 0; next }
    !in_block { print }
  ' "$TARGET_FILE" >"$TARGET_FILE.tmp"

  mv "$TARGET_FILE.tmp" "$TARGET_FILE"
  rm -f "$tmp"
done

# === 4. Zmień nazwę presetu ===
sed -i -E "s|(<meta name=\"arma:PresetName\" content=\")[^\"]*(\" */>)|\1${NEW_PRESET_NAME}\2|" "$TARGET_FILE"
sed -i -E "s|(<h1>Arma 3[[:space:]]*- Preset <strong>)[^<]*(</strong>)|\1${NEW_PRESET_NAME}\2|" "$TARGET_FILE"

echo
echo "✅ Nowy preset zapisany jako: $TARGET_FILE"
