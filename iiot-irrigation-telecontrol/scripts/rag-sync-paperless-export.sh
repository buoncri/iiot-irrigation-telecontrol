#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./scripts/rag-sync-paperless-export.sh [--move] [--dry-run]

Descrizione:
  Sincronizza i documenti esportati da Paperless in appdata/knowledge/raw.

Opzioni:
  --move     Sposta i file da export a raw (default: copia)
  --dry-run  Mostra le azioni senza applicarle
  -h, --help Mostra questo aiuto
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPDATA_DIR="${APPDATA_DIR:-$ROOT_DIR/appdata}"
SRC_DIR="$APPDATA_DIR/paperless/export"
RAW_DIR="$APPDATA_DIR/knowledge/raw"
INDEX_DIR="$APPDATA_DIR/knowledge/index"
LOG_FILE="$INDEX_DIR/paperless-sync-log.csv"

MODE="copy"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --move) MODE="move"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Argomento non valido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$SRC_DIR" "$RAW_DIR" "$INDEX_DIR"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "timestamp,mode,source,destination,status" > "$LOG_FILE"
fi

shopt -s nullglob
FILES=("$SRC_DIR"/*)
shopt -u nullglob

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Nessun file da sincronizzare in $SRC_DIR"
  exit 0
fi

copied=0
moved=0
skipped=0

for src in "${FILES[@]}"; do
  [[ -f "$src" ]] || continue

  name="$(basename "$src")"
  dest="$RAW_DIR/$name"

  if [[ -e "$dest" ]]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    if [[ "$name" == *.* ]]; then
      base="${name%.*}"
      ext="${name##*.}"
      dest="$RAW_DIR/${base}-${ts}.${ext}"
    else
      dest="$RAW_DIR/${name}-${ts}"
    fi
  fi

  now="$(date -Iseconds)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] $MODE: $src -> $dest"
    printf '%s,%s,%s,%s,%s\n' "$now" "$MODE" "$src" "$dest" "dry-run" >> "$LOG_FILE"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$MODE" == "move" ]]; then
    mv "$src" "$dest"
    moved=$((moved + 1))
    printf '%s,%s,%s,%s,%s\n' "$now" "$MODE" "$src" "$dest" "ok" >> "$LOG_FILE"
    echo "MOVED: $name"
  else
    cp "$src" "$dest"
    copied=$((copied + 1))
    printf '%s,%s,%s,%s,%s\n' "$now" "$MODE" "$src" "$dest" "ok" >> "$LOG_FILE"
    echo "COPIED: $name"
  fi
done

echo
echo "Sincronizzazione completata"
echo "copied=$copied"
echo "moved=$moved"
echo "dryrun_or_skipped=$skipped"
echo "log=$LOG_FILE"
