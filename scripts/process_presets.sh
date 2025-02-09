#!/bin/bash
mkdir tmp
cp VT* tmp/

# Sprawdzenie, czy zmienna VERSION jest ustawiona
if [ -z "$VERSION" ]; then
    echo "Błąd: Zmienna VERSION nie jest ustawiona!"
    exit 1
fi

# Przechodzimy przez pliki w katalogu tmp/
for file in tmp/*.html; do
    # Pobieramy nazwę pliku bez katalogu i rozszerzenia
    filename=$(basename "$file" .html)

    # Nowa nazwa pliku z dodanym VERSION
    new_filename="tmp/${filename}${VERSION}.html"

    # Zmieniamy nazwę pliku
    mv "$file" "$new_filename"

    echo "Zmieniono: $file -> $new_filename"
done


for file in tmp/*.html; do 
  filename=$(basename "$file" .html)
  sed -i -E "s|(<h1>Arma 3 - Preset <strong>)[^<]*(</strong></h1>)|\1$filename\2|" "$file"
  sed -i -E "s|(<meta name=\"arma:PresetName\" content=\")[^\"]*(\" />)|\1$filename\2|" "$file"
  echo "Zmieniono $file"
done
