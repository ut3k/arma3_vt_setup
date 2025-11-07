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

  cp "$file" "${file}.backup"
  echo "  💾 Backup zapisany jako: ${file}.backup"

  # Wyciągnięcie wszystkich <tr> w mod-list jako JSON
  local sorted_rows
  sorted_rows=$(pup 'div.mod-list table tr[data-type="ModContainer"] json{}' <"$file" |
    jq -r '
      .[] |
      {
        name: (
          [
            (.children[]? | select(.name=="td") | .children[]? | select(.name=="span" and .attributes["data-type"]=="DisplayName") | .children[]?.text)
          ] | add
        ),
        html: .html
      }
      | select(.name != null and .name != "")
      | [.name, .html] | @tsv
    ' | sort -f -k1,1 | cut -f2-)

  if [ -z "$sorted_rows" ]; then
    echo "  ⚠️  Nie znaleziono żadnych modów — nic do sortowania."
    return
  fi

  # Składanie pliku
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
  echo "  ✅ Gotowe: mody posortowane alfabetycznie."
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
