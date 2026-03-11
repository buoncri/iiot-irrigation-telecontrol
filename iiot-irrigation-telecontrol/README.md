# IIoT Irrigation Telecontrol
> Sistema basato su Docker per la gestione edge e l'automazione locale di impianti di irrigazione, tramite **Dockge**.

## Struttura della Repository
Questa cartella funge da "cuore" del sistema. Mantiene sotto controllo le configurazioni, mentre i dati persistenti (`/opt/appdata`) e il database non vengono tracciati.
- `stacks/`: Cartelle contenenti i file `compose.yaml` (Excalidash, NodeRED, Portainer, ecc.)
- `dockge/`: Configurazione per il demone web di gestione container
- `docs/`: Riferimenti visivi, schemi o screenshot
- `scripts/`: Procedure utili (es. spegnimento/accensione)

## L'entrypoint `.env.global`
Questo file non è su GitHub (per sicurezza), ma deve essere in questa cartella. Contiene la rete master (es. `SYS_IP`). Quando sposti il dispositivo, aggiorna quel file e tutti i container useranno il nuovo indirizzo IP.

## Nuova Installazione
Hai un nuovo PC, un Raspberry o devi fare un "Factory Reset"?
1. Assicurati che il tuo utente abbia permessi sudo.
2. Clona questo repository in `/opt/`.
3. Esegui:
```bash
./bootstrap.sh
```
Il sistema installerà autonomamente Docker, aggiungerà i permessi all'utente, creerà la cartella degli `appdata` e avvierà *Dockge* sulla porta 5001. Dal pannello web potrai far partire il resto.
