# Paperless-AI Stack (Chat-only)

Stack separato per usare Paperless-AI come interfaccia chat intelligente su Paperless.
La scrittura metadati e demandata a Stregatto (writer unico).

## 1) Configurazione

```bash
cd /opt/iiot-irrigation-telecontrol/stacks/paperless_ai
cp .env.example .env
```

Compilare almeno:
- PAPERLESS_API_TOKEN

## 2) Avvio pilot

```bash
cd /opt/iiot-irrigation-telecontrol
./scripts/stackctl.sh up paperless
./scripts/stackctl.sh up ollama
./scripts/stackctl.sh up paperless_ai
```

## 3) Setup iniziale UI

Aprire:
- http://<SYS_IP>:8019/setup

Impostare in UI:
- Paperless URL: http://paperless:8000
- Token API Paperless: token dedicato pilot
- AI provider: ollama
- Ollama URL: http://ollama:11434
- Model: qwen2.5:3b

## 4) Modalita operativa

Per evitare conflitti con Stregatto:
- tenere disattivato processamento automatico
- disattivare tagging/title/document type/correspondent/custom fields in Paperless-AI
- usare Paperless-AI solo per consultazione/chat

## 4b) Workflow Paperless consigliati

Usa i workflow Paperless per instradare i documenti verso Stregatto (writer metadati).
Paperless-AI resta in sola lettura lato metadati.

Dettagli operativi in:
- /opt/iiot-irrigation-telecontrol/docs/paperless-workflows-pilot.md

## 5) Log e stato

```bash
cd /opt/iiot-irrigation-telecontrol
./scripts/stackctl.sh status paperless_ai
./scripts/stackctl.sh logs paperless_ai 200
```
