# Ollama Stack

Stack locale per assistente LLM con backend Ollama e frontend Open WebUI.

## Obiettivo

Fornire Q&A su documenti interni e supporto operativo leggero con consumo risorse contenuto.

## Servizi

- `ollama`: engine inferenza locale (non esposto fuori da `iiot_internal`)
- `ollama_ui`: interfaccia utente web su `OLLAMA_UI_PORT`

## Volumi

- `${APPDATA_DIR}/ollama/models` -> cache modelli
- `${APPDATA_DIR}/ollama/data` -> dati runtime
- `${APPDATA_DIR}/ollama/open-webui` -> utenti/chat/configurazioni UI

## Avvio

```bash
./scripts/stackctl.sh up ollama
```

## Primo bootstrap modello

```bash
docker exec -it ollama ollama pull qwen2.5:7b
```

Per un profilo operativo in italiano, creare il modello derivato:

```bash
docker exec -i ollama ollama create qwen2.5:7b-it -f - <<'EOF'
FROM qwen2.5:7b
SYSTEM """Rispondi sempre in italiano (Italia), salvo richiesta esplicita dell'utente per un'altra lingua.
Mantieni uno stile tecnico, chiaro e operativo, adatto a contesto IIoT e telecontrollo impianti di irrigazione.
Quando mancano dati, dichiaralo chiaramente e proponi verifiche pratiche.
Evita invenzioni: se non sai, dillo.
"""
PARAMETER temperature 0.3
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
EOF
```

Con `DEFAULT_MODELS=qwen2.5:7b-it` Open WebUI usera questo profilo come default.

Per macchine con meno RAM usare un modello piu leggero:

```bash
docker exec -it ollama ollama pull qwen2.5:3b
```

## Note sicurezza

- Lo stack e inserito in `SUSPENDED_STACKS` per evitare riavvii globali involontari.
- Tenere `ENABLE_SIGNUP=False` in ambienti operativi.
- Limitare il dataset RAG a documenti validati in `${APPDATA_DIR}/knowledge/validated`.

## Avvio RAG documentale (fase 1)

Runbook operativo:

- `docs/rag-phase1-runbook.md`

Policy fase 1:

- Open WebUI e l'unica interfaccia RAG attiva.
- Paperless e l'unico entrypoint standard per acquisizione documentazione tecnica.
- Solo i documenti promossi in `${APPDATA_DIR}/knowledge/validated` sono interrogabili.

Script leggeri disponibili:

- `scripts/rag-backlog-report.sh`
- `scripts/rag-promote-validated.sh`

### Signup automatico primo avvio

Lo stack gestisce automaticamente la creazione del primo admin:

- Se il database utenti e vuoto, abilita temporaneamente signup.
- Dopo la creazione del primo utente, al riavvio successivo chiude signup.

Variabili utili in `.env`:

- `AUTO_SIGNUP_ON_EMPTY_DB=True` (consigliato)
- `ENABLE_SIGNUP=False` fallback manuale

## Troubleshooting

### Homepage mostra `http://:8011`

Il problema indica che `SYS_IP` non e valorizzata nel file `.env` dello stack.

1. Verifica `SYS_IP` in `../../.env.global`.
2. Riesegui il bootstrap dalla root progetto per sincronizzare gli `.env` stack:

```bash
cd /opt/iiot-irrigation-telecontrol
./bootstrap.sh
```

3. Riavvia solo lo stack Ollama:

```bash
./scripts/stackctl.sh up ollama
```
