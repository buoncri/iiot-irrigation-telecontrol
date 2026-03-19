#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPDATA_DIR="${APPDATA_DIR:-$ROOT_DIR/appdata}"
RAW_DIR="$APPDATA_DIR/knowledge/raw"
VALIDATED_DIR="$APPDATA_DIR/knowledge/validated"

print_counts_by_ext() {
  local dir="$1"
  local label="$2"

  echo "== $label =="
  if [[ ! -d "$dir" ]]; then
    echo "missing: $dir"
    return 0
  fi

  find "$dir" -maxdepth 1 -type f | sed 's|.*\.||' | tr '[:upper:]' '[:lower:]' | \
    awk '{count[$1]++} END {for (k in count) printf "%s %s\n", count[k], k}' | \
    sort -nr || true
  echo
}

check_naming_convention() {
  local dir="$1"
  local label="$2"
  local regex='^[a-z0-9]+-[a-z0-9]+-[a-z0-9]+-[0-9]{8}-[0-9]{4}-[a-z0-9]+-v[0-9]{2}\.[A-Za-z0-9]+$'

  echo "== Naming check: $label =="
  if [[ ! -d "$dir" ]]; then
    echo "missing: $dir"
    return 0
  fi

  local bad=0
  while IFS= read -r file; do
    local base
    base="$(basename "$file")"
    if [[ ! "$base" =~ $regex ]]; then
      echo "NON-CONFORME: $base"
      bad=1
    fi
  done < <(find "$dir" -maxdepth 1 -type f | sort)

  if [[ "$bad" -eq 0 ]]; then
    echo "ok: nessun file non conforme"
  fi
  echo
}

echo "RAG backlog report"
echo "RAW_DIR=$RAW_DIR"
echo "VALIDATED_DIR=$VALIDATED_DIR"
echo

if [[ -d "$RAW_DIR" ]]; then
  echo "raw_count=$(find "$RAW_DIR" -maxdepth 1 -type f | wc -l)"
else
  echo "raw_count=0"
fi

if [[ -d "$VALIDATED_DIR" ]]; then
  echo "validated_count=$(find "$VALIDATED_DIR" -maxdepth 1 -type f | wc -l)"
else
  echo "validated_count=0"
fi

echo
print_counts_by_ext "$RAW_DIR" "Estensioni in raw"
print_counts_by_ext "$VALIDATED_DIR" "Estensioni in validated"
check_naming_convention "$RAW_DIR" "raw"
check_naming_convention "$VALIDATED_DIR" "validated"

echo "== Prossimi file in raw (max 20) =="
if [[ -d "$RAW_DIR" ]]; then
  find "$RAW_DIR" -maxdepth 1 -type f -printf '%f\n' | sort | head -n 20
fi
