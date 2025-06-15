#!/bin/bash

# Skrypt do sortowania tabeli HTML według kolumny DisplayName
# Użycie: ./sort_html_table.sh [plik.html] lub ./sort_html_table.sh (dla wszystkich plików .html)

INPUT_FILE="$1"

# Funkcja sortująca pojedynczy plik
sort_html_file() {
  local file="$1"

  echo "Sortowanie tabeli w pliku: $file"

  # Sprawdzenie czy plik ma tabelę z modami
  if ! grep -q 'class="mod-list"' "$file" || ! grep -q 'data-type="ModContainer"' "$file"; then
    echo "  - Plik nie zawiera tabeli z modami, pomijam..."
    return
  fi

  # Tworzenie kopii zapasowej
  cp "$file" "${file}.backup"
  echo "  - Utworzono kopię zapasową: ${file}.backup"

  # Tworzenie pliku tymczasowego
  local temp_file=$(mktemp)

  # Wyodrębnienie części przed tabelą
  awk '/<div class="mod-list">/{found=1} !found{print}' "$file" >"$temp_file"

  # Dodanie początku div i table
  echo '    <div class="mod-list">' >>"$temp_file"
  echo '      <table>' >>"$temp_file"

  # Wyodrębnienie wierszy tabeli z data-type="ModContainer", sortowanie i dodanie do pliku
  grep -A 20 'data-type="ModContainer"' "$file" |
    sed '/^--$/d' |
    awk '
    BEGIN { RS="</tr>"; ORS="" }
    /data-type="ModContainer"/ {
        # Wyciągnij nazwę z DisplayName
        match($0, /data-type="DisplayName">([^<]+)</, arr)
        name = arr[1]
        # Przygotuj cały wiersz do sortowania
        gsub(/\n/, " ", $0)  # usuń znaki nowej linii
        print name "\t" $0 "</tr>\n"
    }
    ' |
    sort -f -k1,1 |
    cut -f2- >>"$temp_file"

  # Dodanie końca tabeli i div
  echo '      </table>' >>"$temp_file"
  echo '    </div>' >>"$temp_file"

  # Wyodrębnienie części po tabeli (od dlc-list do końca)
  awk '/class="dlc-list"/{found=1} found{print}' "$file" >>"$temp_file"

  # Przeniesienie posortowanego pliku na miejsce oryginalnego
  mv "$temp_file" "$file"

  echo "  - Gotowe! Tabela została posortowana alfabetycznie."

  # Wyświetlenie pierwszych kilku nazw modów dla weryfikacji
  echo "  - Pierwsze 5 modów po sortowaniu:"
  grep -o 'data-type="DisplayName">[^<]*' "$file" |
    sed 's/data-type="DisplayName">//' |
    head -5 |
    sed 's/^/    /'
  echo ""
}

# Główna logika skryptu
if [ -z "$INPUT_FILE" ]; then
  # Brak parametru - sortuj wszystkie pliki .html
  html_files=(*.html)

  if [ ! -e "${html_files[0]}" ]; then
    echo "Brak plików .html w bieżącym katalogu!"
    exit 1
  fi

  echo "Znaleziono ${#html_files[@]} plik(ów) .html w bieżącym katalogu:"
  for file in "${html_files[@]}"; do
    echo "  - $file"
  done
  echo ""

  read -p "Czy chcesz kontynuować sortowanie wszystkich plików? (t/n): " -n 1 -r
  echo ""

  if [[ ! $REPLY =~ ^[TtYy]$ ]]; then
    echo "Anulowano."
    exit 0
  fi

  echo "Rozpoczynam sortowanie wszystkich plików .html..."
  echo "================================================"

  for file in "${html_files[@]}"; do
    sort_html_file "$file"
  done

  echo "================================================"
  echo "Ukończono sortowanie wszystkich plików!"

else
  # Podano parametr - sortuj konkretny plik
  if [ ! -f "$INPUT_FILE" ]; then
    echo "Błąd: Plik '$INPUT_FILE' nie istnieje!"
    exit 1
  fi

  sort_html_file "$INPUT_FILE"
fi
