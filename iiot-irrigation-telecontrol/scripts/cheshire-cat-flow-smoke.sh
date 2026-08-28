#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./scripts/cheshire-cat-flow-smoke.sh [--token <paperless_api_token>]

Descrizione:
  Smoke test del flow documentale Paperless -> Cheshire Cat.
  Verifica:
  1) raggiungibilita servizi
  2) accesso a Paperless API e conteggio documenti
  3) presenza plugin in Cheshire Cat

Note:
  - Se --token non e fornito, prova PAPERLESS_API_TOKEN in stacks/cheshire_cat/.env
  - In fallback estremo, prova il token presente in appdata/paperless_ai/data/.env
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_ENV="$ROOT_DIR/stacks/cheshire_cat/.env"
PAPERLESS_AI_ENV="$ROOT_DIR/appdata/paperless_ai/data/.env"

TOKEN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)
      TOKEN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Argomento non valido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -f "$STACK_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$STACK_ENV"
fi

CHESHIRE_CAT_PORT="${CHESHIRE_CAT_PORT:-1865}"
PAPERLESS_API_URL="${PAPERLESS_API_URL:-http://127.0.0.1:8018/api}"

# Se si esegue lo smoke dall'host, l'hostname docker interno "paperless" non e risolvibile.
if [[ "$PAPERLESS_API_URL" == http://paperless:* ]]; then
  PAPERLESS_API_URL="http://127.0.0.1:8018/api"
fi

if [[ -z "$TOKEN" && -n "${PAPERLESS_API_TOKEN:-}" ]]; then
  TOKEN="$PAPERLESS_API_TOKEN"
fi

if [[ -z "$TOKEN" && -f "$PAPERLESS_AI_ENV" ]]; then
  TOKEN="$(grep -E '^PAPERLESS_API_TOKEN=' "$PAPERLESS_AI_ENV" | head -n1 | cut -d= -f2- || true)"
fi

echo "[1/4] Verifica UI Cheshire Cat..."
curl -fsS "http://127.0.0.1:${CHESHIRE_CAT_PORT}/admin" >/dev/null
echo "OK: Cheshire Cat UI raggiungibile su porta ${CHESHIRE_CAT_PORT}"

echo "[2/4] Verifica API Paperless..."
if [[ -z "$TOKEN" ]]; then
  echo "ERRORE: PAPERLESS_API_TOKEN assente. Impostalo in stacks/cheshire_cat/.env o usa --token." >&2
  exit 1
fi

DOC_COUNT="$(curl -fsS -H "Authorization: Token ${TOKEN}" "${PAPERLESS_API_URL%/}/documents/?page_size=1" | sed -n 's/.*"count":\([0-9]\+\).*/\1/p')"
if [[ -z "$DOC_COUNT" ]]; then
  echo "ERRORE: risposta Paperless non valida o token non autorizzato" >&2
  exit 1
fi
echo "OK: Paperless raggiungibile, documenti disponibili=${DOC_COUNT}"

echo "[3/4] Verifica cartella plugin Cheshire Cat..."
PLUGIN_DIR="$ROOT_DIR/appdata/cheshire_cat/plugins"
mkdir -p "$PLUGIN_DIR"
PLUGIN_COUNT="$(find "$PLUGIN_DIR" -mindepth 1 -maxdepth 1 | wc -l | awk '{print $1}')"
if [[ "$PLUGIN_COUNT" -eq 0 ]]; then
  echo "WARN: nessun plugin presente in $PLUGIN_DIR"
else
  echo "OK: plugin trovati in $PLUGIN_DIR (count=$PLUGIN_COUNT)"
fi

echo "[4/4] Stato finale flow..."
if [[ "$DOC_COUNT" -gt 0 ]]; then
  echo "READY: servizi, corpus e plugin disponibili. Prossimo passo: verifica utente in chat del flow documentale."
else
  echo "ATTENZIONE: nessun documento in Paperless. Carica almeno un documento per testare il flow."
fi
