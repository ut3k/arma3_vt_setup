#!/bin/bash

INPUT_FILE="$1"

sort_html_file() {
  local file="$1"
  echo "Sortowanie pliku: $file"

  # Sprawdzenie czy plik zawiera mody
  if ! grep -q 'class="mod-list"' "$file" || ! grep -q 'data-type="ModContainer"' "$file"; then
    echo "  - Pomijam: brak modów w pliku."
    return
  fi

  cp "$file" "${file}.backup"
  echo "  - Backup zapisany jako: ${file}.backup"

  local temp_file=$(mktemp)
  local sorted_rows=$(mktemp)

  # Wyciągnij wszystkie <tr>...</tr> w obrębie mod-list
  awk '/<tr data-type="ModContainer">/,/<\/tr>/' "$file" |
    awk 'BEGIN { RS="</tr>"; ORS="" }
         /data-type="DisplayName"/ {
           gsub(/\n/, " ");
           match($0, /data-type="DisplayName">([^<]+)</, a);
           if (a[1] != "") print a[1] "\t<tr" substr($0, index($0, " data-type=\"ModContainer\"")) "</tr>\n"
         }' |
    sort -f -k1,1 |
    cut -f2- >"$sorted_rows"

  # Składanie pliku wynikowego
  awk '
    BEGIN { keep = 1 }
    /<div class="mod-list">/ { print; print "      <table>"; keep = 0 }
    /<\/table>/ && keep == 0 { next }
    /<\/div>/ && keep == 0 { print "      </table>"; print; keep = 1; next }
    keep { print }
  ' "$file" >"$temp_file"

  # Wklej posortowane wiersze do pliku tymczasowego
  sed -i "/<table>/r $sorted_rows" "$temp_file"

  # Zamiana oryginału
  mv "$temp_file" "$file"
  rm "$sorted_rows"

  echo "  - Gotowe. Plik powinien działać w Arma Launcherze."
}

# Logika główna
if [ -z "$INPUT_FILE" ]; then
  html_files=(*.html)
  if [ ! -e "${html_files[0]}" ]; then
    echo "Brak plików HTML!"
    exit 1
  fi
  for file in "${html_files[@]}"; do
    sort_html_file "$file"
  done
else
  if [ ! -f "$INPUT_FILE" ]; then
    echo "Nie znaleziono pliku: $INPUT_FILE"
    exit 1
  fi
  sort_html_file "$INPUT_FILE"
fi
