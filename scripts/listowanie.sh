#!/bin/bash

# Ścieżka do katalogu
BASE_PATH="."

# Przechodzimy do katalogu
cd "$BASE_PATH" || { echo "Nie można przejść do katalogu $BASE_PATH"; exit 1; }

# Tablica na nazwy katalogów (oczyszczone lewe nazwy)
folders=()

# Najpierw generujemy listę w formacie "- ..."
for dir in */; do
    # Usuń trailing slash
    dir="${dir%/}"

    # Lewa część: usuń @ z początku
    left_name="${dir#@}"

    # Prawa część: usuń znaki specjalne
    right_name=$(echo "$left_name" | sed 's/[^a-zA-Z0-9 _-]//g')

    # Dodaj do tablicy nazw katalogów
    folders+=("$left_name:$right_name")

    # Wydrukuj pierwszą listę
    echo "- \"$left_name:/arma3/servermods/@$right_name\""
done

echo ""  # Pusta linia przed YAML

# Teraz generujemy sekcję YAML
for f in "${folders[@]}"; do
    # Podziel na lewą i prawą część
    left_name="${f%%:*}"

    echo "  ${left_name}:"
    echo "    external: true"
done