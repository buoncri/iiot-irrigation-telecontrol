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
setup_docker() {
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

    # Configurazione Utente
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        echo "🔐 Aggiunta utente $USER al gruppo docker..."
        run_privileged usermod -aG docker "$USER"
    fi
}

# ==========================================
# 2. Infrastruttura (Cartelle e Reti Docker)
# ==========================================
setup_infra() {
    echo "🌐 Verifica rete docker globale..."
    # Creazione rete con driver standard se non esiste
    run_privileged docker network create iiot_internal 2>/dev/null || true

    echo "📁 Creazione della directory volumi persistenti: $APPDATA_DIR"
    run_privileged mkdir -p "$APPDATA_DIR"
    run_privileged chown -R "$USER:$USER" "$APPDATA_DIR"

    echo "🎵 Creazione directory media condivisa: $MEDIA_DIR"
    run_privileged mkdir -p "$MEDIA_DIR/music" "$MEDIA_DIR/ingest"
    run_privileged mkdir -p \
        "$MEDIA_DIR/ingest/audio" \
        "$MEDIA_DIR/ingest/video" \
        "$MEDIA_DIR/ingest/foto" \
        "$MEDIA_DIR/ingest/documenti" \
        "$MEDIA_DIR/processed/audio" \
        "$MEDIA_DIR/processed/video" \
        "$MEDIA_DIR/processed/foto" \
        "$MEDIA_DIR/published/formazione" \
        "$MEDIA_DIR/published/report"
    run_privileged chown -R "$USER:$USER" "$MEDIA_DIR"

    echo "🧠 Creazione directory knowledge/procedure in appdata"
    run_privileged mkdir -p \
        "$APPDATA_DIR/knowledge/raw" \
        "$APPDATA_DIR/knowledge/validated" \
        "$APPDATA_DIR/knowledge/index" \
        "$APPDATA_DIR/procedure" \
        "$APPDATA_DIR/training"
    run_privileged chown -R "$USER:$USER" "$APPDATA_DIR/knowledge" "$APPDATA_DIR/procedure" "$APPDATA_DIR/training"

    # Ignition Gateway: crea le directory di persistenza (db e projects).
    # Si montano solo le sottodirectory, così l'immagine gestisce i file base autonomamente.
    local ignition_base="$APPDATA_DIR/ig_cbu_test"
    run_privileged mkdir -p "$ignition_base/db" "$ignition_base/projects"
    run_privileged chown -R 2003:2003 "$ignition_base"
}

# ==========================================
# 3. Entrypoint di rete e Symlink Env
# ==========================================
create_global_env_if_missing() {
    if [ -f "$GLOBAL_ENV" ]; then
        return
    fi

    echo "⚙️  Creazione del file .env.global di base (attendi...)"
    local ip_local
    ip_local=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    [ -z "$ip_local" ] && ip_local="127.0.0.1"
    local domain_local="${HOSTNAME:-telecontrollo}.local"
    cat << ENV_EOF > "$GLOBAL_ENV"
# Configurazione Globale Sistema
SYS_IP=${ip_local}
SYS_DOMAIN=${domain_local}

# Percorso stack Compose (Dockhand)
STACKS_DIR=$PROJECT_DIR/stacks

# Credenziali Database (Configurazione Zero)
POSTGRES_PASSWORD=postgres
APPDATA_DIR=$APPDATA_DIR
MEDIA_DIR=$MEDIA_DIR
ENV_EOF
}

sync_global_env_into_stack_env() {
    local global_env="$1"
    local stack_env="$2"
    local stack_name="$3"
    local changed=0

    while IFS='=' read -r key value; do
        if grep -qE "^${key}=" "$stack_env"; then
            current_line=$(grep -m1 -E "^${key}=" "$stack_env")
            desired_line="${key}=${value}"
            if [ "$current_line" != "$desired_line" ]; then
                escaped_value=$(printf '%s' "$value" | sed -e 's/[\\/&]/\\\\&/g')
                sed -i -E "s|^${key}=.*$|${key}=${escaped_value}|" "$stack_env"
                changed=1
            fi
        else
            printf '%s=%s\n' "$key" "$value" >> "$stack_env"
            changed=1
        fi
    done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$global_env")

    # Rimuove la vecchia chiave DOCKGE_STACKS_DIR, sostituita da STACKS_DIR
    if grep -qE '^DOCKGE_STACKS_DIR=' "$stack_env"; then
        sed -i -E '/^DOCKGE_STACKS_DIR=/d' "$stack_env"
        changed=1
    fi

    if [ "$changed" -eq 1 ]; then
        echo "   -> [$stack_name] chiavi globali sincronizzate"
    else
        echo "   -> [$stack_name] chiavi globali gia' allineate"
    fi
}

align_env_files() {
    echo "🔗 Allineamento file .env per gli stack..."
    ln -sf "../.env.global" "$PROJECT_DIR/dockhand/.env"
    for stack_dir in "$PROJECT_DIR/stacks"/*/; do
        # Salta gli stack dismessi/archiviati
        if [ "$(basename "$stack_dir")" = "_archive" ]; then
            continue
        fi

        if [ -d "$stack_dir" ]; then
            local stack_env="${stack_dir}.env"

            if [ -L "$stack_env" ]; then
                rm "$stack_env"
            fi

            local stack_name
            stack_name="$(basename "$stack_dir")"

            # Se manca, crea il file con base globale + override stack specifico.
            if [ ! -f "$stack_env" ]; then
                cat "$GLOBAL_ENV" > "$stack_env"
                echo "" >> "$stack_env"

                if [ -f "${stack_dir}.env.example" ]; then
                    cat "${stack_dir}.env.example" >> "$stack_env"
                    echo "" >> "$stack_env"
                fi
                echo "   -> [$stack_name] creato da .env.global (+ .env.example se presente)"
            else
                # Sincronizza solo le chiavi globali note, preservando il resto del file stack.
                sync_global_env_into_stack_env "$GLOBAL_ENV" "$stack_env" "$stack_name"
            fi
        fi
    done
}

# ==========================================
# 4. Avvio e Controllo
# ==========================================
start_dockhand() {
    echo "▶️  Avvio del manager Dockhand..."
    cd "$PROJECT_DIR/dockhand"
    run_privileged docker compose up -d
}

setup_docker
setup_infra
create_global_env_if_missing
align_env_files
start_dockhand

echo "✅ Installazione/Ripristino completato con successo!"
echo "   -> Ora tutti i tuoi stack sono visibili da Dockhand."
echo "   -> Per gestire i vecchi volumi orfani puoi usare Portainer."
echo ""
echo "📍 Dockhand: http://localhost:3000"
echo ""
echo "⚠️  IMPORTANTE: Se avevi errori di permessi prima (Docker o Dockhand), digita: newgrp docker"
