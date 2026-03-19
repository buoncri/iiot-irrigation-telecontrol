# RAG Fase 1 - Runbook Operativo Leggero

Questo runbook avvia la fase documentale del RAG con team ridotto.

## Obiettivo

- Fonti: PDF, testo, immagini tecniche
- Ingresso standard: Paperless (upload diretto documentazione tecnica)
- Staging: `appdata/knowledge/raw`
- Corpus interrogabile: `appdata/knowledge/validated`
- Modello default: `qwen2.5:7b-it`

## Policy vincolante fase 1

- Paperless e l'unico entrypoint autorizzato per la documentazione tecnica destinata al RAG.
- Non sono ammessi flussi alternativi in parallelo (upload diretto in raw/validated, altre interfacce RAG, pipeline esterne).
- Open WebUI e l'unica interfaccia RAG attiva in questa fase.
- Il corpus interrogabile resta limitato a `appdata/knowledge/validated`.

## Prerequisiti minimi

```bash
cd /opt/iiot-irrigation-telecontrol
./scripts/stackctl.sh up ollama
./scripts/stackctl.sh up paperless
```

Verifiche rapide:

```bash
docker exec ollama ollama list
./scripts/stackctl.sh status ollama
./scripts/stackctl.sh status paperless
```

## Flusso (10-20 minuti)

1. Operatore
- Carica i nuovi documenti direttamente in Paperless.
- Completa OCR e classificazione base in Paperless.
- Esporta i documenti approvati verso `appdata/knowledge/raw`.

2. Revisore tecnico
- Verifica leggibilita e versione documento.
- Uniforma il nome file secondo convenzione:
  - `<impianto>-<asset>-<tipo>-<YYYYMMDD>-<hhmm>-<autore>-v<nn>.<ext>`

3. Approvatore
- Promuove i file affidabili in `validated` con metadati minimi.

Comando di promozione:

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

## Report backlog

Controllo quotidiano backlog e naming:

```bash
./scripts/rag-backlog-report.sh
```

## KPI fase 1

- Almeno 10 documenti in `raw` processati a settimana
- Almeno 5 documenti validati a settimana
- Qualita risposta su domande tecniche con citazione fonte

## Regole operative

- Open WebUI deve interrogare solo contenuti in `appdata/knowledge/validated`.
- Niente audio/video in fase 1.
- Nessun riavvio globale stack; usare comandi mirati.
- Speckle resta escluso dai cicli globali.
- Paperless-first obbligatorio: ogni documento tecnico entra prima da Paperless.

## Troubleshooting rapido

### Risposte troppo generiche

Se il modello risponde in modo generico, nella maggior parte dei casi il documento non e ancora stato importato nel knowledge base di Open WebUI.

Checklist minima:

1. In Open WebUI crea una Knowledge Base (es. `scada-progetto`).
2. Carica dentro la Knowledge Base il PDF gia validato.
3. Avvia una nuova chat usando il modello `moana:7b-it`.
4. Associa la Knowledge Base alla chat prima di fare domande.
5. Usa domande puntuali e chiedi sempre riferimento alla fonte.

Prompt utile per test:

`Rispondi solo con dati presenti nel documento associato. Cita la sezione o passaggio usato. Se il dato non e presente, scrivi "non presente nel documento".`
