# Materiale AI Builder

- **regia.html**: aprila nel browser sul secondo monitor. Contiene preparazione, quattro lezioni, timer e comandi copiabili. Lo schema si ingrandisce dal pannello laterale. Mantieni `pc-server-tmux.png` nella stessa cartella.
- **REGIA.md**: testo sorgente della regia. Le durate sono una proposta di conduzione da provare in aula; le date dei singoli incontri vanno inserite secondo il calendario docenti.
- **GUIDA-STUDENTI.md**: istruzioni distinte per Mac e Windows, creazione VM, SSH 2222, login Claude, tmux, dashboard ed esempio pronto.
- **pc-server-tmux.png**: schema 1920×1080 per i primi dieci minuti.

Il cloud-init da distribuire è quello **24ORE**, generato dal kit e incluso
nella release candidata. Il bootstrap scarica l’archivio dalla relativa
release GitHub e ne verifica l’impronta; non funziona finché quegli asset non
sono stati pubblicati. Il cloud-init senza `24ore` segue l’edizione precedente.

La regia è una copia dedicata al nuovo corso: non usa il database delle sei
live Alleniamo Imprese. Per aggiornare questa copia, modifica REGIA.md e
rigenera con `python3 tools/crea-regia-24ore.py` dalla radice del kit; l’opzione
`--font PERCORSO` incorpora Manrope nell’HTML.

Prima della diretta resta necessaria una prova del docente su una VM Hetzner
nuova: chiave selezionata in creazione, SSH sui due utenti, firewall,
certificato HTTPS e primo accesso con MFA. I test automatici Linux verificano
installazione, autenticazione SSH, sudo, sessione persistente, secondo avvio
del kit, esempio programmabile e servizio della dashboard. Non creano una VM
Hetzner e non verificano il percorso grafico su un PC Windows.

Hindsight resta un approfondimento da collaudare e non è installato dal kit.
