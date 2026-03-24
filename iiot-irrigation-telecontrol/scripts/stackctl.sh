#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACKS_DIR="$ROOT_DIR/stacks"

# Ordine esplicito per avere avvio/arresto ripetibili.
STACK_ORDER=(
  portainer
  homepage
  flame
  wud
  librenms
  geoserver_cbu
  speckle
  openproject
  beets
  navidrome
  jellyfin
  paperless
  paperless_ai
  cheshire_cat
  ollama
  postgresql_cbu
  utility
  fossflow
  excalidash
  ig_cbu_test
)

# Stack temporaneamente esclusi dai comandi *-active.
SUSPENDED_STACKS=(
  librenms
  openproject
  portainer
  paperless_ai
  cheshire_cat
  speckle
  ollama
)

usage() {
  cat <<'EOF'
Uso:
  ./stackctl.sh list
  ./stackctl.sh list-active
  ./stackctl.sh list-suspended
  ./stackctl.sh up [stack]
  ./stackctl.sh up-active [stack]
  ./stackctl.sh down [stack]
  ./stackctl.sh down-active [stack]
  ./stackctl.sh restart [stack]
  ./stackctl.sh restart-active [stack]
  ./stackctl.sh status [stack]
  ./stackctl.sh status-active [stack]
  ./stackctl.sh pull [stack]
  ./stackctl.sh pull-active [stack]
  ./stackctl.sh update [stack]
  ./stackctl.sh update-active [stack]
  ./stackctl.sh logs <stack> [tail]

Esempi:
  ./stackctl.sh up
  ./stackctl.sh up-active
  ./stackctl.sh up speckle
  ./stackctl.sh status
  ./stackctl.sh logs openproject 200
EOF
}

is_suspended_stack() {
  local stack="$1"
  local suspended
  for suspended in "${SUSPENDED_STACKS[@]}"; do
    if [[ "$suspended" == "$stack" ]]; then
      return 0
    fi
  done
  return 1
}

compose_file_for_stack() {
  local stack="$1"
  local dir="$STACKS_DIR/$stack"

  [[ -d "$dir" ]] || return 1

  if [[ -f "$dir/compose.yaml" ]]; then
    printf '%s' "$dir/compose.yaml"
    return 0
  fi
  if [[ -f "$dir/compose.yml" ]]; then
    printf '%s' "$dir/compose.yml"
    return 0
  fi
  if [[ -f "$dir/docker-compose.yml" ]]; then
    printf '%s' "$dir/docker-compose.yml"
    return 0
  fi

  return 1
}

validate_docker() {
  command -v docker >/dev/null 2>&1 || {
    echo "Errore: docker non trovato nel PATH" >&2
    exit 1
  }
}

run_compose() {
  local stack="$1"
  shift

  local compose_file
  compose_file="$(compose_file_for_stack "$stack")" || {
    echo "[WARN] Stack '$stack' ignorato: file compose non trovato" >&2
    return 0
  }

  local dir file
  dir="$(dirname "$compose_file")"
  file="$(basename "$compose_file")"

  echo "==> [$stack] docker compose -f $file $*"
  (
    cd "$dir"
    docker compose -f "$file" "$@"
  )
}

resolve_targets() {
  local maybe_stack="${1:-}"

  if [[ -n "$maybe_stack" ]]; then
    printf '%s\n' "$maybe_stack"
    return 0
  fi

  printf '%s\n' "${STACK_ORDER[@]}"
}

resolve_active_targets() {
  local maybe_stack="${1:-}"
  local stack

  if [[ -n "$maybe_stack" ]]; then
    if is_suspended_stack "$maybe_stack"; then
      echo "Errore: stack '$maybe_stack' e' sospeso. Usa il comando normale (es. up/down/status) per forzarlo." >&2
      exit 1
    fi
    printf '%s\n' "$maybe_stack"
    return 0
  fi

  for stack in "${STACK_ORDER[@]}"; do
    if ! is_suspended_stack "$stack"; then
      printf '%s\n' "$stack"
    fi
  done
}

main() {
  validate_docker

  local cmd="${1:-}"
  local stack="${2:-}"
  local tail_lines="${3:-200}"

  case "$cmd" in
    list)
      printf '%s\n' "${STACK_ORDER[@]}"
      ;;

    list-active)
      resolve_active_targets
      ;;

    list-suspended)
      printf '%s\n' "${SUSPENDED_STACKS[@]}"
      ;;

    up|start)
      while IFS= read -r target; do
        run_compose "$target" up -d
      done < <(resolve_targets "$stack")
      ;;

    up-active|start-active)
      while IFS= read -r target; do
        run_compose "$target" up -d
      done < <(resolve_active_targets "$stack")
      ;;

    down|stop)
      while IFS= read -r target; do
        run_compose "$target" down
      done < <(resolve_targets "$stack")
      ;;

    down-active|stop-active)
      while IFS= read -r target; do
        run_compose "$target" down
      done < <(resolve_active_targets "$stack")
      ;;

    restart)
      while IFS= read -r target; do
        run_compose "$target" restart
      done < <(resolve_targets "$stack")
      ;;

    restart-active)
      while IFS= read -r target; do
        run_compose "$target" restart
      done < <(resolve_active_targets "$stack")
      ;;

    status|ps)
      while IFS= read -r target; do
        run_compose "$target" ps
      done < <(resolve_targets "$stack")
      ;;

    status-active|ps-active)
      while IFS= read -r target; do
        run_compose "$target" ps
      done < <(resolve_active_targets "$stack")
      ;;

    pull)
      while IFS= read -r target; do
        run_compose "$target" pull
      done < <(resolve_targets "$stack")
      ;;

    pull-active)
      while IFS= read -r target; do
        run_compose "$target" pull
      done < <(resolve_active_targets "$stack")
      ;;

    update)
      while IFS= read -r target; do
        run_compose "$target" pull
        run_compose "$target" up -d
      done < <(resolve_targets "$stack")
      ;;

    update-active)
      while IFS= read -r target; do
        run_compose "$target" pull
        run_compose "$target" up -d
      done < <(resolve_active_targets "$stack")
      ;;

    logs)
      if [[ -z "$stack" ]]; then
        echo "Errore: per 'logs' devi specificare lo stack" >&2
        usage
        exit 1
      fi
      run_compose "$stack" logs --tail "$tail_lines"
      ;;

    -h|--help|help|"")
      usage
      ;;

    *)
      echo "Errore: comando non riconosciuto '$cmd'" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
