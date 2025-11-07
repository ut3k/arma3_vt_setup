# ==============================
#  Arma 3 Preset Generator
#  Alpine + bash + fzf + pup
# ==============================
FROM alpine:3.18

# --- Etap 1: instalacja pakietów systemowych ---
RUN echo "📦 Instaluję pakiety systemowe..." && \
    apk add --no-cache \
      bash \
      curl \
      unzip \
      coreutils \
      fzf \
      jq \
      ca-certificates \
      tar

# --- Etap 2: pobranie PUP z GitHub ---
WORKDIR /tmp
RUN echo "📥 Pobieram PUP (HTML parser) z GitHub..." && \
    curl -fsSL -o pup.zip https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip && \
    unzip pup.zip && \
    chmod +x pup && \
    mv pup /usr/local/bin/pup && \
    rm pup.zip

# --- Etap 3: test instalacji ---
RUN echo "✅ Sprawdzam wersje narzędzi..." && \
    bash --version | head -n 1 && \
    fzf --version | head -n 1 && \
    pup --version

# --- Etap 4: środowisko robocze ---
WORKDIR /work
CMD ["bash"]
