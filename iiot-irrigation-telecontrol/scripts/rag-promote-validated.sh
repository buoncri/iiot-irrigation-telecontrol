#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./scripts/rag-promote-validated.sh --file <nome_file_raw> --impianto <id> --asset <asset> --tipo <tipo> --versione <v> --autore <id> [--note <testo>]

Esempio:
  ./scripts/rag-promote-validated.sh \
    --file imp01-pompaa-manuale-20260319-1015-mrossi-v01.pdf \
    --impianto imp01 --asset pompaa --tipo manuale --versione v01 --autore mrossi \
    --note "manuale validato dal costruttore"
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPDATA_DIR="${APPDATA_DIR:-$ROOT_DIR/appdata}"
RAW_DIR="$APPDATA_DIR/knowledge/raw"
VALIDATED_DIR="$APPDATA_DIR/knowledge/validated"
LOG_FILE="$APPDATA_DIR/knowledge/validation-log.csv"

FILE=""
IMPIANTO=""
ASSET=""
TIPO=""
VERSIONE=""
AUTORE=""
NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --impianto) IMPIANTO="$2"; shift 2 ;;
    --asset) ASSET="$2"; shift 2 ;;
    --tipo) TIPO="$2"; shift 2 ;;
    --versione) VERSIONE="$2"; shift 2 ;;
    --autore) AUTORE="$2"; shift 2 ;;
    --note) NOTE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Argomento non valido: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$FILE" || -z "$IMPIANTO" || -z "$ASSET" || -z "$TIPO" || -z "$VERSIONE" || -z "$AUTORE" ]]; then
  echo "Errore: argomenti obbligatori mancanti"
  usage
  exit 1
fi

mkdir -p "$RAW_DIR" "$VALIDATED_DIR"

SRC="$RAW_DIR/$FILE"
if [[ ! -f "$SRC" ]]; then
  echo "Errore: file non trovato in raw: $SRC"
  exit 1
fi

DEST="$VALIDATED_DIR/$FILE"
if [[ -f "$DEST" ]]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  EXT="${FILE##*.}"
  BASE="${FILE%.*}"
  DEST="$VALIDATED_DIR/${BASE}-${TS}.${EXT}"
fi

mv "$SRC" "$DEST"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "timestamp,filename,source_path,destination_path,impianto,asset,tipo,versione,autore,status,note" > "$LOG_FILE"
fi

NOW="$(date -Iseconds)"
DEST_NAME="$(basename "$DEST")"
printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
  "$NOW" "$DEST_NAME" "$SRC" "$DEST" "$IMPIANTO" "$ASSET" "$TIPO" "$VERSIONE" "$AUTORE" "validated" "$NOTE" >> "$LOG_FILE"

echo "OK: promosso in validated -> $DEST"
echo "Log aggiornato -> $LOG_FILE"
