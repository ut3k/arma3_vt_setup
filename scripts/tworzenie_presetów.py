from bs4 import BeautifulSoup
import copy

# ==========================
# KONFIGURACJA
# ==========================
SOURCE_FILE = "VT_ARMADA_.html"
FIRST_PRESET_NAME = "VT_PHANTOM_"
SECOND_PRESET_NAME = "VT_VENOM_"
# ==========================


def load_mods(file_path):
    """Wczytuje mody z preset HTML."""
    with open(file_path, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'html.parser')
    mods = []
    for tr in soup.select('tr[data-type="ModContainer"]'):
        name = tr.find('td', {'data-type': 'DisplayName'}).text.strip()
        mods.append({"name": name, "tr": tr})
    return mods, soup


def print_mod_list(mods):
    """Wyświetla numerowaną listę modów."""
    print("\n📦 Lista modów w preset:")
    for i, mod in enumerate(mods, start=1):
        print(f"{i:>3}. {mod['name']}")
    print()


def ask_mods_to_remove(mods):
    """Pozwala użytkownikowi wybrać numery modów do usunięcia."""
    choice = input("Podaj numery modów do usunięcia (oddzielone przecinkami, Enter = nic nie usuwać): ").strip()
    if not choice:
        return []
    try:
        indices = [int(x.strip()) for x in choice.split(",") if x.strip().isdigit()]
        to_remove = [mods[i - 1]["name"] for i in indices if 1 <= i <= len(mods)]
        return to_remove
    except Exception as e:
        print(f"❌ Błąd w danych wejściowych: {e}")
        return []

def make_preset(original_soup, mods, mods_to_remove, new_name):
    """Tworzy nowy preset HTML na podstawie oryginału bez pustych linii w tabeli modów."""
    soup = copy.deepcopy(original_soup)

    # Zmień nazwę w meta i tytule
    meta = soup.find("meta", {"name": "arma:PresetName"})
    if meta:
        meta["content"] = new_name
    strong = soup.find("strong")
    if strong:
        strong.string = new_name
    h1 = soup.find("h1")
    if h1:
        h1.string = f"Arma 3 - Preset {new_name}"

    # Usuń mody
    for tr in soup.select('tr[data-type="ModContainer"]'):
        name = tr.find('td', {'data-type': 'DisplayName'}).text.strip()
        if name in mods_to_remove:
            tr.decompose()

    # Znajdź tabelę z modami i usuń puste linie tylko w jej wnętrzu
    table = soup.find("table")
    if table:
        cleaned_lines = []
        for line in str(table).splitlines():
            if line.strip() != "":
                cleaned_lines.append(line)
        # Zamień starą tabelę na czystą wersję
        table.replace_with(BeautifulSoup("\n".join(cleaned_lines), "html.parser"))

    # Zapisz
    out_name = f"{new_name}.html"
    with open(out_name, "w", encoding="utf-8") as f:
        f.write(str(soup))

    print(f"✅ Utworzono preset: {out_name}\n")

def main():
    # Wczytaj oryginał
    mods, soup = load_mods(SOURCE_FILE)
    print_mod_list(mods)

    # ====== PIERWSZY PRESET (PHANTOM) ======
    print(f"🛠️ Tworzenie presetu: {FIRST_PRESET_NAME}")
    to_remove_first = ask_mods_to_remove(mods)
    make_preset(soup, mods, to_remove_first, FIRST_PRESET_NAME)

    # ====== DRUGI PRESET (VENOM) ======
    print_mod_list(mods)
    print(f"🛠️ Tworzenie presetu: {SECOND_PRESET_NAME}")
    to_remove_second = ask_mods_to_remove(mods)
    make_preset(soup, mods, to_remove_second, SECOND_PRESET_NAME)

    print("🎉 Gotowe! Oba presety utworzone.")


if __name__ == "__main__":
    main()