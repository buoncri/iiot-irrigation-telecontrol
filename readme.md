# IIoT Telecontrollo Irrigazione

Repository di orchestrazione per una piattaforma IIoT di telecontrollo impianti di irrigazione industriale basata su Docker Compose.

Questo progetto centralizza:
- stack applicativi (`/opt/stacks/*`)
- dati persistenti (`/opt/appdata/*`)
- utility di gestione (es. Dockge, Portainer)

L'obiettivo e' avere una base ordinata, versionabile e pronta per evolvere dopo il primo commit.

## Panoramica

Componenti principali rilevati nel workspace:
- `dockge/`: gestione stack Compose via UI (`DOCKGE_STACKS_DIR=/opt/stacks`)
- `stacks/`: definizioni stack Compose per servizi applicativi
- `appdata/`: volumi bind e dati applicativi persistenti
- `portainer/`: stack di gestione container
- `containerd/`: componenti runtime/container toolchain locali

Stack presenti in `stacks/`:
- `homepage`
- `beets`
- `excalidash`
- `flame`
- `fossflow`
- `ig_cbu_test`
- `librenms`
- `openproject`
- `postgresql_cbu`
- `speckle`
- `utility`
- `wud`

## Struttura Repository

```text
/opt
|- readme.md
|- dockge/
|- stacks/
|  |- homepage/
|  |- openproject/
|  |- ...
|- appdata/
|  |- homepage/
|  |- openproject/
|  |- ...
|- portainer/
`- ...
```

## Prerequisiti

- Linux host con accesso shell
- Docker Engine installato e attivo
- Docker Compose plugin (`docker compose`)
- Permessi utente per usare Docker (`docker` group o sudo)

Verifica rapida:

```bash
docker --version
docker compose version
docker info >/dev/null && echo "Docker OK"
```

## Avvio Rapido

### 1) Avviare Dockge (gestione stack)

Da `dockge/`:

```bash
docker compose up -d
```

Accesso previsto: `http://<host>:5001`

Nota: la configurazione attuale monta `- /opt/stacks:/opt/stacks`, quindi gli stack vengono letti direttamente da questa repository.

### 2) Avviare uno stack applicativo

Esempio con Homepage:

```bash
cd /opt/stacks/homepage
docker compose up -d
```

Per tutti gli stack, ripetere nella relativa cartella `stacks/<nome>/`.

### 3) Verifica stato

```bash
docker ps
docker compose -f /opt/stacks/homepage/compose.yaml ps
```

## Operazioni Comuni

Avvio/stop stack:

```bash
cd /opt/stacks/<nome-stack>
docker compose up -d
docker compose down
```

Aggiornamento immagini:

```bash
cd /opt/stacks/<nome-stack>
docker compose pull
docker compose up -d
```

Log recenti:

```bash
cd /opt/stacks/<nome-stack>
docker compose logs --tail=200
```

## Gestione Centralizzata con stackctl.sh

Per gestire tutti gli stack da root senza entrare ogni volta nelle singole cartelle, usare lo script `stackctl.sh`.

Preparazione:

```bash
cd /opt
chmod +x stackctl.sh
```

Comandi principali:

```bash
# Elenco stack gestiti
./stackctl.sh list

# Elenco stack attivi/sospesi
./stackctl.sh list-active
./stackctl.sh list-suspended

# Avvio/arresto di tutti gli stack
./stackctl.sh up
./stackctl.sh down

# Avvio/arresto di soli stack attivi (esclude i sospesi)
./stackctl.sh up-active
./stackctl.sh down-active

# Operazioni su un solo stack
./stackctl.sh up speckle
./stackctl.sh status openproject
./stackctl.sh logs openproject 200

# Aggiornamento immagini e riallineamento servizi
./stackctl.sh update
```

Nota: lo script rileva automaticamente se uno stack usa `compose.yaml`, `compose.yml` o `docker-compose.yml`.

## Networking Docker (Standard)

Obiettivo: networking semplice e sicuro, con isolamento per stack e scambio dati inter-app solo dove serve.

Regole adottate:
- rete condivisa tra applicazioni: `iiot_internal` (external) per integrazioni cross-stack e Homepage
- database/cache non esposti verso host se non necessario
- porte pubbliche solo per i servizi che devono essere raggiunti dall'esterno
- stack in introduzione (es. Speckle) sospesi dai comandi `*-active`

Creazione rete condivisa (una tantum):

```bash
docker network ls --format '{{.Name}}' | grep -qx 'iiot_internal' || docker network create iiot_internal
```

Verifica veloce:

```bash
docker network inspect iiot_internal --format '{{range $id,$c := .Containers}}{{$c.Name}} {{end}}'
./stackctl.sh status-active
```

## Bootstrap Nuovo Impianto

Obiettivo: mantenere `stacks/` come sola configurazione e `appdata/` come sola persistenza.

Passi consigliati:

```bash
# 1) Preparare i file env locali dai template
cd /opt
for f in stacks/*/.env.example; do cp -n "$f" "${f%.example}"; done

# 2) Creare le directory dati principali
mkdir -p \
	/opt/appdata/flame/data \
	/opt/appdata/speckle/postgres-data \
	/opt/appdata/speckle/redis-data \
	/opt/appdata/speckle/minio-data

# 3) Avviare e verificare
./stackctl.sh up-active
./stackctl.sh status-active
```

Regola operativa:
- in `stacks/` solo compose, `.env.example` e file di configurazione
- in `/opt/appdata` tutti i dati runtime/persistenti

## Persistenza Dati

I dati sono distribuiti principalmente in:
- `/opt/appdata/*`
- eventuali directory dati interne agli stack (es. `postgres-data`, `minio-data`, `uploads`, `db`)

Prima di modifiche rilevanti agli stack:
1. fermare i servizi interessati
2. eseguire backup delle directory dati
3. applicare modifiche
4. riavviare e verificare log/healthcheck

Esempio backup semplice:

```bash
sudo tar -czf /opt/backup_appdata_$(date +%F).tar.gz /opt/appdata
```

## Convenzioni Consigliate

- un file `compose.yaml` (o `docker-compose.yml`) per cartella stack
- configurazioni e segreti fuori dal controllo versione quando sensibili
- nomi stack coerenti tra cartella e servizio principale
- evitare modifiche manuali nei volumi database a caldo

## Stato Attuale e Prossimi Passi

Stato: base repository presente con stack multipli e dati locali.

Per consolidare il primo commit e' consigliato:
1. ricontrollare `.gitignore` mirato (escludere DB dump/volumi pesanti/sensibili)
2. ricontrollare `README.md` specifici nei singoli stack piu' critici
3. documentare porte e credenziali bootstrap in un file operativo separato non pubblico
4. definire una procedura standard di backup/restore per ogni servizio stato-centrico

## Disclaimer

Questo repository contiene anche directory dati runtime. Prima di pubblicare o condividere il progetto, verificare con attenzione la presenza di file sensibili (password, token, dump DB, certificati, chiavi).
