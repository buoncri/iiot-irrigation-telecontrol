#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./scripts/rag-ask-ollama.sh --question "<domanda>" [--model <modello>] [--max-files N] [--max-chars N] [--show-context]

Esempio:
  ./scripts/rag-ask-ollama.sh --question "Qual e la pressione massima della pompa A?"
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPDATA_DIR="${APPDATA_DIR:-$ROOT_DIR/appdata}"
VALIDATED_DIR="$APPDATA_DIR/knowledge/validated"

# Carica eventuale default modello dallo stack Ollama.
if [[ -f "$ROOT_DIR/stacks/ollama/.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/stacks/ollama/.env"
fi

DEFAULT_MODEL="${DEFAULT_MODELS:-moana:7b-it}"

QUESTION=""
MODEL="$DEFAULT_MODEL"
MAX_FILES=5
MAX_CHARS=12000
SHOW_CONTEXT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --question) QUESTION="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --max-files) MAX_FILES="$2"; shift 2 ;;
    --max-chars) MAX_CHARS="$2"; shift 2 ;;
    --show-context) SHOW_CONTEXT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Argomento non valido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$QUESTION" ]]; then
  echo "Errore: --question obbligatoria" >&2
  usage
  exit 1
fi

if ! [[ "$MAX_FILES" =~ ^[0-9]+$ ]] || (( MAX_FILES < 1 )); then
  echo "Errore: --max-files deve essere un intero >= 1" >&2
  exit 1
fi

if ! [[ "$MAX_CHARS" =~ ^[0-9]+$ ]] || (( MAX_CHARS < 500 )); then
  echo "Errore: --max-chars deve essere un intero >= 500" >&2
  exit 1
fi

if [[ ! -d "$VALIDATED_DIR" ]]; then
  echo "Errore: directory corpus non trovata: $VALIDATED_DIR" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Errore: docker non disponibile" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx 'ollama'; then
  echo "Errore: container ollama non in esecuzione. Avvia con ./scripts/stackctl.sh up ollama" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
CTX_FILE="$TMP_DIR/context.txt"

question_regex="$(printf '%s' "$QUESTION" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | awk 'length($0)>=4' | sort -u | paste -sd'|' -)"

mapfile -t all_files < <(find "$VALIDATED_DIR" -maxdepth 1 -type f | sort)
if [[ ${#all_files[@]} -eq 0 ]]; then
  echo "Errore: nessun file disponibile in $VALIDATED_DIR" >&2
  exit 1
fi

declare -a selected_files=()

if [[ -n "$question_regex" ]] && command -v rg >/dev/null 2>&1; then
  mapfile -t matched_files < <(rg -i -l "$question_regex" "$VALIDATED_DIR" -g '*' || true)
  for f in "${matched_files[@]}"; do
    selected_files+=("$f")
    [[ ${#selected_files[@]} -ge $MAX_FILES ]] && break
  done
fi

if [[ ${#selected_files[@]} -eq 0 ]]; then
  for f in "${all_files[@]}"; do
    selected_files+=("$f")
    [[ ${#selected_files[@]} -ge $MAX_FILES ]] && break
  done
fi

if [[ ${#selected_files[@]} -eq 0 ]]; then
  echo "Errore: nessun file selezionato dal corpus" >&2
  exit 1
fi

{
  echo "## CONTESTO RAG"
  echo "Usa solo le informazioni nei frammenti seguenti."
  echo
} > "$CTX_FILE"

current_chars=0
for f in "${selected_files[@]}"; do
  name="$(basename "$f")"
  ext="${name##*.}"
  ext_lc="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  chunk=""

  if [[ "$ext_lc" == "pdf" ]]; then
    if command -v pdftotext >/dev/null 2>&1; then
      chunk="$(pdftotext "$f" - 2>/dev/null | tr -d '\000' | head -c 3500 || true)"
    else
      chunk="[PDF non parsabile: installare poppler-utils per estrazione testo]"
    fi
  else
    chunk="$(tr -d '\000' < "$f" | head -c 3500 || true)"
  fi

  [[ -n "$chunk" ]] || continue

  block="\n[FONTE: $name]\n$chunk\n"
  block_len="$(printf '%s' "$block" | wc -c | awk '{print $1}')"

  if (( current_chars + block_len > MAX_CHARS )); then
    remaining=$((MAX_CHARS - current_chars))
    if (( remaining > 80 )); then
      printf '%s' "$block" | head -c "$remaining" >> "$CTX_FILE"
      current_chars=$MAX_CHARS
    fi
    break
  fi

  printf '%s' "$block" >> "$CTX_FILE"
  current_chars=$((current_chars + block_len))
done

PROMPT_FILE="$TMP_DIR/prompt.txt"
cat > "$PROMPT_FILE" <<EOF
Sei un assistente tecnico IIoT per telecontrollo irrigazione.
Rispondi in italiano.
Usa solo le informazioni nel contesto.
Se l'informazione non e presente, rispondi esattamente: "non presente nel documento".
Cita sempre almeno una fonte nel formato [FONTE: nomefile].

DOMANDA:
$QUESTION

CONTESTO:
$(cat "$CTX_FILE")
EOF

if [[ "$SHOW_CONTEXT" -eq 1 ]]; then
  echo "----- CONTESTO USATO -----"
  cat "$CTX_FILE"
  echo "--------------------------"
fi

echo "Modello: $MODEL"
echo "File contestuali: ${#selected_files[@]}"
echo

OLLAMA_IP="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ollama)"
if [[ -z "$OLLAMA_IP" ]]; then
  echo "Errore: impossibile risolvere IP container ollama" >&2
  exit 1
fi

REQ_FILE="$TMP_DIR/request.json"
RESP_FILE="$TMP_DIR/response.json"

python3 - <<'PY' "$MODEL" "$PROMPT_FILE" > "$REQ_FILE"
import json
import sys

model = sys.argv[1]
prompt_path = sys.argv[2]

with open(prompt_path, "r", encoding="utf-8") as fh:
    prompt = fh.read()

print(json.dumps({
    "model": model,
    "prompt": prompt,
    "stream": False,
}, ensure_ascii=False))
PY

if ! curl -sS --max-time "${OLLAMA_API_TIMEOUT:-300}" \
  -H 'Content-Type: application/json' \
  --data-binary "@$REQ_FILE" \
  "http://$OLLAMA_IP:11434/api/generate" > "$RESP_FILE"; then
  echo "Errore: chiamata API Ollama fallita o andata in timeout" >&2
  exit 1
fi

python3 - <<'PY' "$RESP_FILE"
import json
import sys

resp_path = sys.argv[1]
with open(resp_path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

if payload.get("error"):
    raise SystemExit(f"Errore Ollama API: {payload['error']}")

print(payload.get("response", ""))
PY
