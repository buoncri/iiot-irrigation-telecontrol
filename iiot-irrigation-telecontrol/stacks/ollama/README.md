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

Per macchine con meno RAM usare un modello piu leggero:

```bash
docker exec -it ollama ollama pull qwen2.5:3b
```

## Note sicurezza

- Lo stack e inserito in `SUSPENDED_STACKS` per evitare riavvii globali involontari.
- Tenere `ENABLE_SIGNUP=False` in ambienti operativi.
- Limitare il dataset RAG a documenti validati in `${APPDATA_DIR}/knowledge/validated`.

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
