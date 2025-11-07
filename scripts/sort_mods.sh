#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-}"

sort_html_file() {
  local file="$1"
  echo "📄 Sortowanie pliku: $file"

  # Sprawdzenie, czy w pliku są mody
  if ! grep -q 'class="mod-list"' "$file" || ! grep -q 'data-type="ModContainer"' "$file"; then
    echo "  ⚠️  Pomijam: brak modów w pliku."
    return
  fi

  # Backup
  cp "$file" "${file}.backup"
  echo "  💾 Backup zapisany jako: ${file}.backup"

  # 1️⃣ Wyciągnij listę modów z pełnym wierszem <tr> i nazwą
  local rows
  rows=$(pup 'div.mod-list tr[data-type="ModContainer"]' <"$file")

  # 2️⃣ Podziel to na osobne rekordy (każdy <tr> w osobnym pliku)
  # Użyj pup, aby wyciągnąć nazwę moda z DisplayName i sortuj alfabetycznie
  local sorted_rows
  sorted_rows=$(echo "$rows" | pup 'tr json{}' | jq -r '.[] | {
    name: (.children[]?.children[]? | select(.text != null) | .text)?,
    html: (.html)
  } | select(.name != null) | [.name, .html] | @tsv' |
    sort -f -k1,1 | cut -f2-)

  # 3️⃣ Odbuduj cały plik HTML z posortowaną tabelą
  local temp_file
  temp_file=$(mktemp)

  awk -v block="$sorted_rows" '
    BEGIN { keep = 1 }
    /<div class="mod-list">/ {
      print; print "      <table>";
      print block;
      print "      </table>";
      keep = 0; next
    }
    /<\/div>/ && keep == 0 { print; keep = 1; next }
    keep { print }
  ' "$file" >"$temp_file"

  mv "$temp_file" "$file"

  echo "  ✅ Gotowe: mody w pliku posortowane alfabetycznie."
}

# Logika główna
if [ -z "$INPUT_FILE" ]; then
  html_files=(*.html)
  if [ ! -e "${html_files[0]}" ]; then
    echo "❌ Brak plików HTML w katalogu!"
    exit 1
  fi
  for file in "${html_files[@]}"; do
    sort_html_file "$file"
  done
else
  if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Nie znaleziono pliku: $INPUT_FILE"
    exit 1
  fi
  sort_html_file "$INPUT_FILE"
fi
