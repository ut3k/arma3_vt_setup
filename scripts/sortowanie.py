import os
from bs4 import BeautifulSoup

folder_path = "./"  # folder z plikami HTML

for filename in os.listdir(folder_path):
    if filename.endswith(".html"):
        file_path = os.path.join(folder_path, filename)
        
        # Wczytaj HTML
        with open(file_path, "r", encoding="utf-8") as file:
            soup = BeautifulSoup(file, "html.parser")
        
        # Znajdź tabelę z modami
        mod_table_div = soup.find("div", class_="mod-list")
        if not mod_table_div:
            continue
        mod_table = mod_table_div.find("table")
        if not mod_table:
            continue
        
        # Pobierz wszystkie wiersze z modami
        rows = mod_table.find_all("tr", {"data-type": "ModContainer"})
        
        # Sortowanie po nazwie
        def get_mod_name(row):
            td = row.find("td", {"data-type": "DisplayName"})
            return td.text.strip().lower() if td else ""
        
        sorted_rows = sorted(rows, key=get_mod_name)
        
        # Budujemy nową tabelę w HTML jako string
        new_table_html = ""
        for row in sorted_rows:
            row_str = str(row).replace("\n", "").replace("  ", "")  # jeden <tr> w jednej linii
            new_table_html += row_str + "\n"  # każdy <tr> w jednej linii, nowa linia oddziela wiersze
        
        # Zamieniamy starą tabelę na nową
        mod_table.clear()
        mod_table.append(BeautifulSoup(new_table_html, "html.parser"))
        
        # Zapisz nadpisując oryginalny plik
        with open(file_path, "w", encoding="utf-8") as file:
            file.write(str(soup))
        
        print(f"Posortowano i zapisano: {filename}")