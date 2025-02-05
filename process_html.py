import os
import re

VERSION = os.environ.get('VERSION')

def process_html_file(file):
    new_file = file.replace('.html', f'_v{VERSION}.html')
    with open(file, 'r') as f:
        data = f.read()
    
    # Zastąpienie wzorców za pomocą wyrażeń regularnych
    data = re.sub(r'<meta name="arma:PresetName" content="[^"]*">', f'<meta name="arma:PresetName" content="{file.replace(".html", "")}_{VERSION}">', data)
    data = re.sub(r'<h1>Arma 3 - Preset <strong>[^<]*</strong></h1>', f'<h1>Arma 3 - Preset <strong>{file.replace(".html", "")}_{VERSION}</strong></h1>', data)

    with open(new_file, 'w') as f:
        f.write(data)
    return new_file

# Zmień na odpowiednią ścieżkę do Twoich plików HTML
files = [file for file in os.listdir('.') if file.endswith('.html')]

modified_files = []
for file in files:
    modified_file = process_html_file(file)
    modified_files.append(modified_file)

# Zapisanie nazw zmodyfikowanych plików do pliku
with open('release_files.txt', 'w') as f:
    f.write('\n'.join(modified_files))
