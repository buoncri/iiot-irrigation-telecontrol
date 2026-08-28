# Workflow Paperless per pilot con Stregatto + Paperless-AI

Obiettivo: usare Paperless come orchestratore, Stregatto come writer metadati,
Paperless-AI solo per chat/consultazione intelligente.

## Tag di riferimento

- `pilot-ppai`: documento nel perimetro AI pilot.
- `pilot-ppai-excluded`: documento escluso esplicitamente dal pilot.
- `no-ai`: esclusione assoluta (privacy/sensibilita/rumore).

## Workflow consigliati

## 1) Intake pilot

- Trigger: documento aggiunto.
- Condizioni suggerite:
  - filename contiene pattern di progetto (es. `0846ES`), oppure
  - document type in set tecnico/progetto/sistema.
- Azioni:
  - aggiungi tag `pilot-ppai`.

Risultato: i documenti candidati entrano nel perimetro AI senza selezione manuale continua.

## 2) Esclusione prioritaria

- Trigger: documento aggiunto o aggiornato.
- Condizione: presenza tag `no-ai`.
- Azioni:
  - rimuovi tag `pilot-ppai`.
  - aggiungi tag `pilot-ppai-excluded`.

Risultato: la policy di esclusione prevale sempre.

## 3) Normalizzazione metadata base (Stregatto)

- Trigger: documento aggiunto.
- Condizioni: pattern su filename/corrispondente/tipo documento.
- Azioni:
  - setta correspondent.
  - setta document type.
  - aggiungi tag tecnici base.

Risultato: riduci variabilita a monte e demandi la scrittura metadati a Stregatto.

## Parametri stack Paperless-AI collegati (chat-only)

Nel file [stacks/paperless_ai/.env](stacks/paperless_ai/.env):

- `DISABLE_AUTOMATIC_PROCESSING=yes`
- `ADD_AI_PROCESSED_TAG=no`
- `ACTIVATE_TAGGING=no`
- `ACTIVATE_CORRESPONDENTS=no`
- `ACTIVATE_DOCUMENT_TYPE=no`
- `ACTIVATE_TITLE=no`
- `ACTIVATE_CUSTOM_FIELDS=no`

Questo impedisce a Paperless-AI di modificare metadati su Paperless.

## Avvio progressivo consigliato

1. Attiva i workflow in Paperless.
2. Verifica che i documenti target ricevano i tag di routing.
3. Esegui Stregatto per la scrittura metadati.
4. Usa Paperless-AI per chat su documenti gia catalogati.

## Verifica veloce

- In Paperless: controlla che i documenti target ricevano `pilot-ppai`.
- In Paperless-AI: verifica che non vengano aggiunti/alterati metadati.
- In caso di errore: applica tag `no-ai` e riesegui il ciclo.
