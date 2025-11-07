import sys
import os
import glob
from bs4 import BeautifulSoup
from bs4.element import Tag # Importowanie Tag

# Funkcja do sortowania wierszy
def sort_mod_preset(filepath):
    """Parsuje plik presetu Arma 3, sortuje listę modów alfabetycznie i zapisuje zmiany."""
    try:
        # 1. Wczytanie i parsowanie pliku
        # Używamy 'html.parser', ale odczytujemy jako XML, by zachować tagi <table />
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Używamy 'xml' jako parsera, który jest bardziej tolerancyjny dla składni <table />
        soup = BeautifulSoup(content, 'xml') 
        
        # 2. Znalezienie tabeli modów (wewnątrz div class="mod-list")
        mod_list_div = soup.find('div', class_='mod-list')
        if not mod_list_div:
            return False, "Brak bloku mod-list."

        table = mod_list_div.find('table')
        if not table:
            return False, "Brak tabeli modów."

        # Znajdujemy wszystkie wiersze modów.
        rows = table.find_all('tr', attrs={'data-type': 'ModContainer'})
        
        if not rows:
            return False, "Brak wierszy modów do sortowania."
        
        # 3. Ekstrakcja danych i sortowanie
        mod_data = []
        
        # Ważne: musimy zachować kolejność oryginalnych wierszy, które nie są modami (jeśli takie są)
        # W presetach Arma 3 to zazwyczaj nie występuje, ale to jest bezpieczniejsze.
        
        # Iterujemy po wszystkich wierszach <tr>, aby tylko wiersze 'ModContainer' zostały posortowane.
        for row in rows:
            # DisplayName jest w pierwszym <td> z atrybutem data-type="DisplayName"
            display_name_tag = row.find('td', attrs={'data-type': 'DisplayName'})
            
            if display_name_tag and display_name_tag.string:
                mod_name = display_name_tag.string.strip()
                # extract() usuwa wiersz z drzewa (przygotowanie do ponownego wstawienia)
                mod_data.append((mod_name, row.extract())) 
            else:
                # W poprawnym prescie każdy <tr> powinien mieć DisplayName. 
                # Jeśli tu dotrzemy, to jest problem ze strukturą.
                pass 
        
        # Sortowanie alfabetyczne (ignorując wielkość liter)
        mod_data.sort(key=lambda x: x[0].lower())

        # 4. Ponowne wstawienie posortowanych wierszy
        for _, row in mod_data:
            table.append(row)
        
        # 5. Zapisanie posortowanego pliku
        # Używamy encode() i dekodujemy, aby uzyskać prosty string, a następnie naprawiamy deklarację XML
        # To pozwala zachować oryginalne formatowanie atrybutów i tagów jak <table />
        output_str = soup.encode(formatter=None).decode('utf-8')
        
        # Korekta deklaracji XML, by była zgodna z oryginalnym formatem
        output_str = output_str.replace('<?xml version="1.0" encoding="utf-8"?>', '<?xml version="1.0" encoding="utf-8"?>')
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(output_str)

        return True, ""
        
    except Exception as e:
        # Bardziej szczegółowy komunikat o błędzie Pythona
        return False, f"BŁĄD PARSOWANIA: {str(e)}"


# ---------- Główna logika skryptu (bez zmian) ----------

SORTED_COUNT = 0
files_pattern = os.path.join('..', '*.html')
files = glob.glob(files_pattern)

print("Rozpoczynam sortowanie list modów w plikach .html w bieżącym katalogu...")
print("--------------------------------------------------------")

if not files:
    print("Brak plików .html do przetworzenia. Zakończono.")
    sys.exit(0)

for filepath in files:
    print(f"Przetwarzam: {filepath}")
    
    success, message = sort_mod_preset(filepath)
    
    if success:
        print("   ✅ Posortowano i zaktualizowano pomyślnie.")
        SORTED_COUNT += 1
    else:
        print(f"   ⚠️ Pomijam/BŁĄD: {message}")

print("--------------------------------------------------------")
print(f"Zakończono. Posortowano {SORTED_COUNT} pliki presetu Arma 3 (.html).")
