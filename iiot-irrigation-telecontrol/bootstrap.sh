#!/bin/bash
# =========================================================================
# IIoT Irrigation Telecontrol - Setup & Bootstrap Script
# =========================================================================
set -e # Interrompe in caso di errori gravi

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Permette di eseguire passi previlegiati
if [ "$(id -u)" != "0" ] && [ -z "$SUDO_USER" ]; then
    echo "Questo script proverà a elevare i permessi con sudo quando necessario."
fi

# Percorsi principali
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV="${PROJECT_DIR}/.env.global"
APPDATA_DIR="$PROJECT_DIR/appdata"
MEDIA_DIR="$PROJECT_DIR/media"

echo "🚀 Inizio procedura di bootstrap o riparazione..."

# ==========================================
# 1. Dipendenze e Docker
# ==========================================
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    echo "📦 Installazione di Docker e plugin Compose..."
    run_privileged apt-get update
    run_privileged apt-get install -y ca-certificates curl docker.io docker-compose
fi

echo "🐳 Verifica servizio Docker in esecuzione..."
if ! run_privileged docker info >/dev/null 2>&1; then
    if command -v systemctl >/dev/null 2>&1; then
        # Su Linux con systemd abilita e avvia Docker all'avvio del sistema.
        run_privileged systemctl enable docker >/dev/null 2>&1 || true
        run_privileged systemctl start docker
    elif command -v service >/dev/null 2>&1; then
        run_privileged service docker start
    fi
fi

if ! run_privileged docker info >/dev/null 2>&1; then
    echo "❌ Docker risulta installato ma non in esecuzione."
    echo "   Avvia il servizio con: sudo systemctl start docker"
    exit 1
fi

# 2. Configurazione Utente
if ! groups "$USER" | grep -q '\bdocker\b'; then
    echo "🔐 Aggiunta utente $USER al gruppo docker..."
    run_privileged usermod -aG docker "$USER"
fi

# ==========================================
# 3. Infrastruttura (Cartelle e Reti Docker)
# ==========================================
echo "🌐 Verifica rete docker globale..."
# Creazione rete con driver standard se non esiste
run_privileged docker network create iiot_internal 2>/dev/null || true

echo "📁 Creazione della directory volumi persistenti: $APPDATA_DIR"
run_privileged mkdir -p "$APPDATA_DIR"
run_privileged chown -R "$USER:$USER" "$APPDATA_DIR"

echo "🎵 Creazione directory media condivisa: $MEDIA_DIR"
run_privileged mkdir -p "$MEDIA_DIR/music" "$MEDIA_DIR/ingest"
run_privileged chown -R "$USER:$USER" "$MEDIA_DIR"

# Ignition Gateway: crea le directory di persistenza (db e projects).
# Si montano solo le sottodirectory, così l'immagine gestisce i file base autonomamente.
IGNITION_BASE="$APPDATA_DIR/ig_cbu_test"
run_privileged mkdir -p "$IGNITION_BASE/db" "$IGNITION_BASE/projects"
run_privileged chown -R 2003:2003 "$IGNITION_BASE"

# ==========================================
# 4. Entrypoint di rete e Symlink Env
# ==========================================
if [ ! -f "$GLOBAL_ENV" ]; then
    echo "⚙️  Creazione del file .env.global di base (attendi...)"
    IP_LOCAL=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    [ -z "$IP_LOCAL" ] && IP_LOCAL="127.0.0.1"
    DOMAIN_LOCAL="${HOSTNAME:-telecontrollo}.local"
    cat << ENV_EOF > "$GLOBAL_ENV"
# Configurazione Globale Sistema
SYS_IP=${IP_LOCAL}
SYS_DOMAIN=${DOMAIN_LOCAL}

# Percorso Dockge
DOCKGE_STACKS_DIR=$PROJECT_DIR/stacks

# Credenziali Database (Configurazione Zero)
POSTGRES_PASSWORD=postgres
APPDATA_DIR=$APPDATA_DIR
MEDIA_DIR=$MEDIA_DIR
ENV_EOF
fi

echo "🔗 Allineamento file .env per gli stack..."
ln -sf "../.env.global" "$PROJECT_DIR/dockge/.env"
for stack_dir in "$PROJECT_DIR/stacks"/*/; do
    if [ -d "$stack_dir" ]; then
        stack_env="${stack_dir}.env"

        if [ -L "$stack_env" ]; then
            rm "$stack_env"
        fi

        # Non sovrascrive gli .env esistenti: evita perdita di personalizzazioni locali.
        if [ ! -f "$stack_env" ]; then
            cat "$GLOBAL_ENV" > "$stack_env"
            echo "" >> "$stack_env"

            if [ -f "${stack_dir}.env.example" ]; then
                cat "${stack_dir}.env.example" >> "$stack_env"
                echo "" >> "$stack_env"
            fi
        fi
    fi
done

# ==========================================
# 5. Avvio e Controllo
# ==========================================
echo "▶️  Avvio del manager Dockge..."
cd "$PROJECT_DIR/dockge"
run_privileged docker compose up -d

echo "✅ Installazione/Ripristino completato con successo!"
echo "   -> Ora tutti i tuoi stack sono visibili da Dockge."
echo "   -> Per gestire i vecchi volumi orfani puoi usare Portainer."
echo ""
echo "📍 Dockge: http://localhost:5001"
echo ""
echo "⚠️  IMPORTANTE: Se avevi errori di permessi prima (Docker o Dockge), digita: newgrp docker"
