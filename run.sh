#!/usr/bin/env bash
set -euo pipefail

# === Arma Preset Tools Launcher ===
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker/generate_presets/docker-compose.yml"
DOCKERFILE_DIR="$REPO_ROOT/docker/generate_presets"
IMAGE_NAME="arma3_presets_image:latest"

echo "=== Arma Preset Tools ==="
echo "Repo root: $REPO_ROOT"
echo

# Sprawdzenie dostępności Dockera
HAS_DOCKER=false
DOCKER_COMPOSE_CMD=""

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    HAS_DOCKER=true
    echo "🐳 Docker dostępny i mamy dostęp do demona"
    # Sprawdzenie compose plugin lub klasycznego binarnego
    if docker compose version >/dev/null 2>&1; then
      DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
      DOCKER_COMPOSE_CMD="docker-compose"
    fi
  else
    echo "⚠️  Docker zainstalowany, ale brak dostępu (permission denied)."
    echo "👉 Uruchom z sudo lub dodaj użytkownika do grupy docker:"
    echo "   sudo usermod -aG docker \$USER"
    echo
  fi
else
  echo "⚠️  Docker nie jest zainstalowany — działanie lokalne."
fi

echo
echo "Wybierz opcję:"
echo "1) Generuj preset PHANTOM"
echo "2) Generuj preset VENOM"
echo "3) Sortuj mody (scripts/sort_mods.sh)"
echo "0) Wyjście"
echo
read -rp "Twój wybór: " choice
echo

# === Pomocnicze funkcje ===

run_in_docker() {
  local cmd="$1"
  if ! $HAS_DOCKER; then
    echo "❌ Docker niedostępny."
    return 1
  fi

  if [ -n "$DOCKER_COMPOSE_CMD" ] && [ -f "$COMPOSE_FILE" ]; then
    echo "➡ Uruchamiam przez compose jako UID=$(id -u):$(id -g)"
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" run --rm -it --user $(id -u):$(id -g) presets $cmd
    return $?
  fi

  echo "⚠️  Brak compose – uruchamiam docker run."
  echo "➡ Buduję obraz z $DOCKERFILE_DIR..."
  docker build -t "$IMAGE_NAME" "$DOCKERFILE_DIR"
  docker run --rm -it \
    -v "$REPO_ROOT":/work \
    -w /work \
    --user $(id -u):$(id -g) \
    "$IMAGE_NAME" bash -c "$cmd"
}

run_local() {
  local cmd="$1"
  echo "➡ Uruchamiam lokalnie: $cmd"
  bash -c "$cmd"
}

# === Menu akcji ===
case "$choice" in
1)
  echo "🚀 Generuję preset PHANTOM..."
  if $HAS_DOCKER; then
    run_in_docker "scripts/gen_phantom.sh"
  else
    run_local "scripts/gen_phantom.sh"
  fi
  ;;
2)
  echo "🚀 Generuję preset VENOM..."
  if $HAS_DOCKER; then
    run_in_docker "scripts/gen_venom.sh"
  else
    run_local "scripts/gen_venom.sh"
  fi
  ;;
  fi
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
