#!/bin/bash

# Używamy katalogu, w którym znajduje się ten skrypt (scripts) jako punktu odniesienia
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PYTHON_SCRIPT="sort_mods.py"

# Sprawdzenie, czy Python jest zainstalowany
if ! command -v python3 &>/dev/null; then
  echo "BŁĄD: Python 3 nie znaleziony."
  echo "Zainstaluj go w kontenerze/systemie: apk add python3"
  exit 1
fi

# 1. Przechodzimy do katalogu scripts (gdzie jest plik .py)
cd "$SCRIPT_DIR"

# 2. Sprawdzenie, czy skrypt Pythona istnieje
if [ ! -f "$PYTHON_SCRIPT" ]; then
  echo "BŁĄD: Nie znaleziono skryptu $PYTHON_SCRIPT w katalogu $SCRIPT_DIR."
  # Wracamy do poprzedniego katalogu roboczego (dla czystości)
  cd - >/dev/null
  exit 1
fi

# 3. Uruchomienie skryptu Pythona
echo "➡ Uruchamiam skrypt Pythona z katalogu $SCRIPT_DIR..."
# Pliki HTML, które chcemy posortować (VT_*.html), są w katalogu nadrzędnym (../)
python3 "$PYTHON_SCRIPT"
