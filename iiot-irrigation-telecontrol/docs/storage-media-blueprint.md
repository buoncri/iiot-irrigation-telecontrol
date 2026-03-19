# Storage e Flussi Media - Implementazione Iniziale

Questo documento definisce la baseline operativa per storage, media e knowledge nel sistema di telecontrollo irrigazione.

## 1) Layout directory

### Appdata

- `${APPDATA_DIR}/knowledge/raw`: documenti non validati
- `${APPDATA_DIR}/knowledge/validated`: documenti validati per consultazione e LLM
- `${APPDATA_DIR}/knowledge/index`: dati indicizzazione locale
- `${APPDATA_DIR}/procedure`: procedure operative standard
- `${APPDATA_DIR}/training`: materiali formazione finalizzati

### Media

- `${MEDIA_DIR}/ingest/audio`: audio grezzo in ingresso
- `${MEDIA_DIR}/ingest/video`: video grezzo in ingresso
- `${MEDIA_DIR}/ingest/foto`: foto grezze in ingresso
- `${MEDIA_DIR}/ingest/documenti`: allegati documentali in ingresso
- `${MEDIA_DIR}/processed/audio`: audio normalizzato
- `${MEDIA_DIR}/processed/video`: video normalizzato/compresso
- `${MEDIA_DIR}/processed/foto`: immagini ridimensionate e annotate
- `${MEDIA_DIR}/published/formazione`: contenuti finali per formazione
- `${MEDIA_DIR}/published/report`: allegati finali per report intervento

## 2) Regole di naming minime

Formato consigliato:

`<impianto>-<asset>-<tipo>-<YYYYMMDD>-<hhmm>-<autore>-v<nn>.<ext>`

Esempio:

`imp01-pompaA-video-manutenzione-20260319-1015-mrossi-v01.mp4`

Metadati minimi da tracciare nei report:

- impianto
- area o asset (pompa/valvola/quadro/rtu)
- tipo intervento
- autore
- timestamp
- esito (ok/ko/parziale)

## 3) Flusso operativo ridotto (team piccolo)

1. Operatore carica file in `${MEDIA_DIR}/ingest/*`.
2. Tecnico valida e normalizza in `${MEDIA_DIR}/processed/*`.
3. Materiale approvato va in `${MEDIA_DIR}/published/formazione` o `${MEDIA_DIR}/published/report`.
4. Documenti procedurali e manuali vengono consolidati in `${APPDATA_DIR}/knowledge/validated`.
5. LLM locale consulta solo `${APPDATA_DIR}/knowledge/validated`.

## 4) Retention 180 giorni

- Online: mantenere i contenuti in `${MEDIA_DIR}/published/*` fino a 180 giorni.
- Archivio: dopo 180 giorni spostare su storage freddo/offline.
- Eccezioni: incidenti o non conformita restano online finche non chiusi.

## 5) Backup essenziale (host singolo)

- Giornaliero: snapshot `appdata` + `media/published`.
- Settimanale: full `appdata` + `media`.
- Restore test: almeno 1 volta al mese su directory di test.

Comando base suggerito:

```bash
tar -czf /backup/iiot_$(date +%F).tar.gz appdata media/published
```

## 6) Scope implementato in questa fase

- Stack `stacks/ollama` creato e pronto.
- `bootstrap.sh` aggiornato con directory standard media/knowledge.
- `scripts/stackctl.sh` aggiornato con stack `ollama` sospeso di default.

Prossimo passo consigliato: creare script di retention/archiviazione automatica e check periodico integrita backup.

## 7) Riferimento operativo RAG Fase 1

Per il flusso documentale leggero (team ridotto) usare il runbook:

- `docs/rag-phase1-runbook.md`

Script di supporto:

- `scripts/rag-backlog-report.sh`
- `scripts/rag-promote-validated.sh`

Policy attuale fase 1:

- Paperless e l'entrypoint standard e unico per documentazione tecnica destinata al RAG.
- Open WebUI e l'unica interfaccia RAG attiva.
- Il dataset interrogabile resta `appdata/knowledge/validated`.
