#!/bin/bash
# =========================================================================
# IIoT Irrigation Telecontrol - Setup & Bootstrap Script
# =========================================================================
set -e # Interrompe in caso di errori gravi

# Permette di eseguire passi previlegiati
if [ "$(id -u)" != "0" ] && [ -z "$SUDO_USER" ]; then
    echo "Questo script proverà a elevare i permessi con sudo quando necessario."
fi

# Percorsi principali
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV="${PROJECT_DIR}/.env.global"
APPDATA_DIR="$PROJECT_DIR/appdata"

echo "🚀 Inizio procedura di bootstrap o riparazione..."

# ==========================================
# 1. Dipendenze e Docker
# ==========================================
if ! command -v docker >/dev/null 2>&1; then
    echo "📦 Installazione di Docker e plugin Compose..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl docker.io docker-compose
fi

# 2. Configurazione Utente
if ! groups "$USER" | grep -q '\bdocker\b'; then
    echo "🔐 Aggiunta utente $USER al gruppo docker..."
    sudo usermod -aG docker "$USER"
fi

# ==========================================
# 3. Infrastruttura (Cartelle e Reti Docker)
# ==========================================
echo "🌐 Verifica rete docker globale..."
# Creazione rete con driver standard se non esiste
sudo docker network create iiot_internal 2>/dev/null || true

echo "📁 Creazione della directory volumi persistenti: $APPDATA_DIR"
sudo mkdir -p "$APPDATA_DIR"
sudo chown -R "$USER:$USER" "$APPDATA_DIR"

# ==========================================
# 4. Entrypoint di rete e Symlink Env
# ==========================================
if [ ! -f "$GLOBAL_ENV" ]; then
    echo "⚙️  Creazione del file .env.global di base (attendi...)"
    IP_LOCAL=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1) || "192.168.0.6"
    DOMAIN_LOCAL="${HOSTNAME:-telecontrollo}.local"
    cat << ENV_EOF > "$GLOBAL_ENV"
# Configurazione Globale Sistema
SYS_IP=${IP_LOCAL}
SYS_DOMAIN=${DOMAIN_LOCAL}

# Percorso Dockge
DOCKGE_STACKS_DIR=$PROJECT_DIR/stacks

# Credenziali Database (Configurazione Zero)
POSTGRES_PASSWORD=postgres
ENV_EOF
fi

echo "🔗 Ricostruzione symlink .env (se mancano)..."
ln -sf "../.env.global" "$PROJECT_DIR/dockge/.env"
for stack_dir in "$PROJECT_DIR/stacks"/*/; do
    if [ -d "$stack_dir" ]; then
        ln -sf "../../.env.global" "${stack_dir}.env"
    fi
done

# ==========================================
# 5. Avvio e Controllo
# ==========================================
echo "▶️  Avvio del manager Dockge..."
cd "$PROJECT_DIR/dockge"
sudo docker compose up -d

echo "✅ Installazione/Ripristino completato con successo!"
echo "   -> Ora tutti i tuoi stack sono visibili da Dockge."
echo "   -> Per gestire i vecchi volumi orfani puoi usare Portainer."
echo ""
echo "📍 Dockge: http://localhost:5001"
echo ""
echo "⚠️  IMPORTANTE: Se avevi errori di permessi prima (Docker o Dockge), digita: newgrp docker"
