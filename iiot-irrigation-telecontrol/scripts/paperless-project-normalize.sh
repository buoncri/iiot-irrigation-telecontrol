#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./scripts/paperless-project-normalize.sh \
    --project-code 0846ES \
    --correspondent "Consorzio Bonificazione Umbra" \
    --document-type "Elaborato Progetto"

Descrizione:
  Normalizza metadati Paperless per un set documentale di progetto:
  - assegna tag coerenti a tutti i documenti del progetto
  - imposta correspondent e document type (se mancanti o null)

Regole selezione documenti progetto:
  match case-insensitive su title/original_file_name/archived_file_name.

Prerequisiti:
  - token API in stacks/cheshire_cat/.env (PAPERLESS_API_TOKEN)
  - Paperless raggiungibile su http://127.0.0.1:8018/api
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_ENV="$ROOT_DIR/stacks/cheshire_cat/.env"

PROJECT_CODE=""
CORRESPONDENT_NAME=""
DOCUMENT_TYPE_NAME=""
PAPERLESS_API_URL="http://127.0.0.1:8018/api"
TOKEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-code)
      PROJECT_CODE="$2"
      shift 2
      ;;
    --correspondent)
      CORRESPONDENT_NAME="$2"
      shift 2
      ;;
    --document-type)
      DOCUMENT_TYPE_NAME="$2"
      shift 2
      ;;
    --paperless-api-url)
      PAPERLESS_API_URL="$2"
      shift 2
      ;;
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

if [[ -z "$PROJECT_CODE" || -z "$CORRESPONDENT_NAME" || -z "$DOCUMENT_TYPE_NAME" ]]; then
  echo "Errore: --project-code, --correspondent e --document-type sono obbligatori" >&2
  usage
  exit 1
fi

if [[ -z "$TOKEN" && -f "$STACK_ENV" ]]; then
  TOKEN="$(grep -E '^PAPERLESS_API_TOKEN=' "$STACK_ENV" | head -n1 | cut -d= -f2- || true)"
fi

if [[ -z "$TOKEN" ]]; then
  echo "Errore: token assente. Usa --token o valorizza PAPERLESS_API_TOKEN in stacks/cheshire_cat/.env" >&2
  exit 1
fi

python3 - <<'PY' "$PAPERLESS_API_URL" "$TOKEN" "$PROJECT_CODE" "$CORRESPONDENT_NAME" "$DOCUMENT_TYPE_NAME"
import json
import sys
import urllib.request
from urllib.parse import quote_plus

base = sys.argv[1].rstrip('/')
token = sys.argv[2].strip()
project_code = sys.argv[3].strip()
correspondent_name = sys.argv[4].strip()
document_type_name = sys.argv[5].strip()

headers = {
    'Authorization': f'Token {token}',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
}

mandatory_tags = [
    'progetto',
    'categoria-elaborati_progetto',
    f'progetto-{project_code.lower()}',
    'consorzio-bonificazione-umbra',
    'set-esempio-progetto',
]


def request_json(method, url, payload=None):
    data = None
    if payload is not None:
        data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode('utf-8')
        return json.loads(raw) if raw else {}


def iter_results(path):
    url = f"{base}{path}"
    while url:
        data = request_json('GET', url)
        for item in data.get('results', []):
            yield item
        url = data.get('next')


def get_or_create_tag(name):
    q = quote_plus(name)
    found = list(iter_results(f"/tags/?page_size=100&name__iexact={q}"))
    for t in found:
        if (t.get('name') or '').strip().lower() == name.lower():
            return t['id']
    created = request_json('POST', f"{base}/tags/", {'name': name})
    return created['id']


def get_or_create_correspondent(name):
    q = quote_plus(name)
    found = list(iter_results(f"/correspondents/?page_size=100&name__icontains={q}"))
    for c in found:
        if (c.get('name') or '').strip().lower() == name.lower():
            return c['id']
    created = request_json('POST', f"{base}/correspondents/", {'name': name, 'matching_algorithm': 6, 'is_insensitive': True})
    return created['id']


def get_or_create_document_type(name):
    q = quote_plus(name)
    found = list(iter_results(f"/document_types/?page_size=100&name__icontains={q}"))
    for d in found:
        if (d.get('name') or '').strip().lower() == name.lower():
            return d['id']
    created = request_json('POST', f"{base}/document_types/", {'name': name, 'matching_algorithm': 6, 'is_insensitive': True})
    return created['id']


print(f"[INFO] project_code={project_code}")

tag_ids = [get_or_create_tag(t) for t in mandatory_tags]
correspondent_id = get_or_create_correspondent(correspondent_name)
document_type_id = get_or_create_document_type(document_type_name)

print(f"[INFO] ensured_tags={len(tag_ids)} correspondent_id={correspondent_id} document_type_id={document_type_id}")

project_docs = []
needle = project_code.lower()
for d in iter_results('/documents/?page_size=100'):
    hay = ' '.join([
        str(d.get('title') or ''),
        str(d.get('original_file_name') or ''),
        str(d.get('archived_file_name') or ''),
    ]).lower()
    if needle in hay:
        project_docs.append(d)

print(f"[INFO] matched_docs={len(project_docs)}")

updated = 0
for d in project_docs:
    old_tags = d.get('tags') or []
    new_tags = sorted(set(old_tags + tag_ids))

    payload = {'tags': new_tags}

    # solo se mancanti/null; non sovrascrive metadata utente gia impostati.
    if not d.get('correspondent'):
        payload['correspondent'] = correspondent_id
    if not d.get('document_type'):
        payload['document_type'] = document_type_id

    if payload.get('tags') != old_tags or 'correspondent' in payload or 'document_type' in payload:
        request_json('PATCH', f"{base}/documents/{d['id']}/", payload)
        updated += 1

print(f"[OK] updated_docs={updated}")
PY
