# Il kit della macchina: Agenti che non dormono

Il kit che prepara la macchina del corso "Agenti che non dormono" di
AlleniamoImprese. Non si installa a mano: quando crei il server su Hetzner
incolli nel campo cloud-init il testo della release, e la macchina fa da sola.

## Cosa fa

Alla prima accensione, come root:

1. Scarica l'archivio della release e ne controlla l'impronta SHA256. Se
   l'impronta non torna, si ferma e non installa niente.
2. Imposta il fuso orario italiano e gli aggiornamenti di sicurezza
   automatici.
3. Crea l'utente `agente`, senza password e senza poteri di amministratore:
   Claude lavora con questo utente.
4. Spegne il server SSH: da fuori non si entra. La macchina si usa dalla
   console del pannello Hetzner e dal telefono.
5. Installa Claude Code dal repository firmato di Anthropic, con
   l'aggiornamento automatico spento, pronto per il login.
6. Installa Bun e il plugin Telegram ufficiale di Claude Code.
7. Fa partire la sessione di Claude in tmux come servizio dell'utente
   `agente`: riparte da sola dopo un riavvio, con Remote Control acceso.
8. Sulla console apre un menu: entrare nella sessione, controllo salute, QR
   per il login, riavvio della sessione.

## Scelte di sicurezza

- L'agente non è amministratore.
- Nessuna porta aperta verso l'esterno; il kit non scrive password di root.
- Password, chiavi e token non passano mai dalla conversazione con Claude: si
  inseriscono dal menu della console.
- Il testo di cloud-init fissa l'impronta dell'archivio: la macchina esegue
  solo la versione provata.

## Se qualcosa non va

- `/var/log/agenti-kit-install.log`: tutto quello che ha fatto
  l'installazione.
- `/var/lib/agenti-kit/stato`: l'esito di ogni passo, `ok` o `da-completare`.
- Da root l'installazione si può rilanciare: `bash /opt/agenti-kit/install.sh`.

## Versioni

Ogni versione è una release con l'archivio e il testo di cloud-init.

- `v0.1`: prima prova su una macchina Hetzner vera.

## Per chi sviluppa il kit

- `python3 tools/crea-rilascio.py vX.Y`: archivio, impronta e testo di
  cloud-init in `dist/`.
- `test/prova-docker.sh`: installazione in un contenitore Ubuntu 24.04,
  lanciata due volte, poi i controlli di `test/verifica-installazione.sh`.
- `test/prova-qr-login.sh`: il QR del login da un indirizzo lungo.
