# Credenziali di default degli stack

> ⚠️ Queste sono le credenziali **di partenza** (valori di default definiti negli `.env.example` / `.env.global`). Vanno cambiate in produzione, soprattutto per i servizi esposti fuori dalla rete `iiot_internal`.

## Database (configurazione zero)

| Variabile | Valore di default | Dove |
|---|---|---|
| `POSTGRES_PASSWORD` | `postgres` | `.env.global`, propagata a tutti gli stack che non la sovrascrivono |

## Stack attivi

| Stack | Servizio | Utente | Password | Note |
|---|---|---|---|---|
| `geoserver_cbu` | GeoServer admin | `admin` | `admin` | `GEOSERVER_ADMIN_USER` / `GEOSERVER_ADMIN_PASSWORD` |
| `ig_cbu_test` | Ignition Gateway | `admin` | `admin` | `GATEWAY_ADMIN_USERNAME` / `GATEWAY_ADMIN_PASSWORD` |
| `paperless` | Paperless-ngx web | `admin` | `admin` | `PAPERLESS_ADMIN_USER` / `PAPERLESS_ADMIN_PASSWORD` |
| `paperless` | Postgres interno | `paperless` | `paperless` | `PAPERLESS_DBUSER` / `PAPERLESS_DBPASS` |
| `openproject` | Web UI | `admin` | `admin` | Password richiesta al primo login, non da `.env` |
| `openproject` | Postgres interno | `postgres` | `p4ssw0rd` | override locale di `POSTGRES_PASSWORD` |
| `postgresql_cbu` | PostGIS | `postgres` | `postgres` | eredita `POSTGRES_PASSWORD` globale |
| `dockhand` | Web UI | — | — | nessuna credenziale di default in `.env`, impostata al primo accesso |

## Stack archiviati (`stacks/_archive/`)

| Stack | Servizio | Utente | Password | Note |
|---|---|---|---|---|
| `librenms` | MariaDB | `librenms` | `asupersecretpassword` | `MYSQL_USER` / `MYSQL_PASSWORD` |
| `librenms` | SMTP (esempio) | `foo` | `bar` | valori placeholder, non funzionanti |
| `speckle` | Postgres interno | `speckle` | `speckle` | `SPECKLE_POSTGRES_USER` / `SPECKLE_POSTGRES_PASSWORD` |
| `flame` | Accesso pannello | — | `flame_password` | `FLAME_PASSWORD` |

## Stack senza credenziali di default (setup al primo accesso)

`beets`, `excalidash`, `fossflow`, `homepage`, `jellyfin`, `navidrome`, `ollama`, `utility` — nessuna variabile di autenticazione predefinita negli `.env.example`; l'account amministratore va creato al primo avvio tramite wizard/UI del servizio.
