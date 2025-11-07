#!/usr/bin/env bash
set -euo pipefail

# === Arma Preset Tools Launcher ===
# Używamy ścieżki względnej do określenia katalogu głównego repozytorium
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker/generate_presets/docker-compose.yml"

echo "=== Arma Preset Tools ==="
echo "Repo root: $REPO_ROOT"
echo

# --- WERYFIKACJA DOCKERA ---

DOCKER_COMPOSE_CMD=""

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ BŁĄD: Docker nie jest zainstalowany."
  echo "👉 Proszę zainstalować Docker Engine."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "❌ BŁĄD: Docker jest zainstalowany, ale **nie masz uprawnień** do uruchomienia demona Dockera."
  echo "👉 Aby naprawić, dodaj się do grupy docker i uruchom ponownie terminal:"
  echo "   sudo usermod -aG docker \$USER"
  exit 1
fi

# Sprawdzenie dostępności compose (plugin lub binarny)
if docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE_CMD="docker-compose"
else
  echo "❌ BŁĄD: Nie znaleziono narzędzia Docker Compose (docker compose lub docker-compose)."
  echo "👉 Upewnij się, że masz zainstalowane Docker Compose."
  exit 1
fi

echo "🐳 Docker i Docker Compose są gotowe do użycia."
echo

# === Pomocnicza funkcja (Tylko Docker Compose) ===

run_in_docker() {
  local cmd="$1"
  local service_name="${2:-presets}" # Ustawienie domyślnej usługi na 'presets'

  echo "➡ Uruchamiam przez compose jako UID=$(id -u):$(id -g) w usłudze $service_name"
  # Używamy zmiennej $DOCKER_COMPOSE_CMD, $service_name i $cmd
  $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" run --rm -it --user "$(id -u):$(id -g)" "$service_name" bash -c "$cmd"
  return $?
}

# === MENU GŁÓWNE ===

echo "Wybierz opcję:"
echo "1) Generuj preset PHANTOM"
echo "2) Generuj preset VENOM"
echo "3) Sortuj mody"
echo "0) Wyjście"
echo
read -rp "Twój wybór: " choice
echo

# === Menu akcji (Uproszczone) ===
case "$choice" in
1)
  echo "🚀 Generuję preset PHANTOM..."
  # Uruchamiamy gen_phantom.sh w domyślnej usłudze 'presets'
  run_in_docker "scripts/gen_phantom.sh" "presets"
  ;;
2)
  echo "🚀 Generuję preset VENOM..."
  # Uruchamiamy gen_venom.sh w domyślnej usłudze 'presets'
  run_in_docker "scripts/gen_venom.sh" "presets"
  ;;
3)
  echo "🔧 Sortuję pliki HTML..."
  # Uruchamiamy skrypt Pythona w usłudze 'sorter'
  run_in_docker "python3 scripts/sort_mods.py" "sorter"
  ;;
0)
  echo "👋 Do zobaczenia!"
  exit 0
  ;;
*)
  echo "❌ Nieprawidłowy wybór."
  exit 1
  ;;
esac
