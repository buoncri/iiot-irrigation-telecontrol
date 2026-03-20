# RAG Fase 1 - Runbook Essenziale

Runbook minimo per ottenere risposte Ollama istruite da documenti caricati via Paperless.

## Scope utile

- Entrypoint documenti: `appdata/paperless/export`
- Staging: `appdata/knowledge/raw`
- Corpus interrogabile: `appdata/knowledge/validated`
- Query: `scripts/rag-ask-ollama.sh`

## Prerequisiti

```bash
cd /opt/iiot-irrigation-telecontrol
./scripts/stackctl.sh up paperless
./scripts/stackctl.sh up ollama
```

Per migliorare l'estrazione testo dai PDF:

```bash
sudo apt-get update && sudo apt-get install -y poppler-utils
```

## Pipeline minima (operativa)

1. Carica ed esporta da Paperless in `appdata/paperless/export`.
2. Sincronizza export in raw:

```bash
./scripts/rag-sync-paperless-export.sh
```

3. Promuovi il documento affidabile in validated:

```bash
./scripts/rag-promote-validated.sh \
  --file imp01-pompaa-manuale-20260319-1015-mrossi-v01.pdf \
  --impianto imp01 \
  --asset pompaa \
  --tipo manuale \
  --versione v01 \
  --autore mrossi \
  --note "documento costruttore verificato"
```

4. Interroga Ollama con contesto dai file validati:

```bash
./scripts/rag-ask-ollama.sh --question "Quali sono i limiti operativi della pompa A?"
```

## Comandi utili

```bash
./scripts/rag-backlog-report.sh
./scripts/rag-sync-paperless-export.sh --dry-run
./scripts/rag-ask-ollama.sh --question "<domanda>" --show-context
```

## Regole minime

- Paperless-first: niente upload diretto in raw/validated.
- Solo `knowledge/validated` e interrogabile.
- Nessun riavvio globale stack.
- Speckle resta escluso dai cicli globali.
