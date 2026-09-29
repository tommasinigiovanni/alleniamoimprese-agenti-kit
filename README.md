# Il kit della macchina: Agenti che non dormono

Il kit che prepara la macchina del corso "Agenti che non dormono" di
AlleniamoImprese. Non si installa a mano: quando crei il server su Hetzner
incolli nel campo cloud-init il testo della release, e la macchina fa da sola.

Il kit fa solo il pavimento. tmux, Claude e Remote Control li accendi tu: è
quello che si impara nel corso.

## Cosa fa

Alla prima accensione, come root:

1. Scarica l'archivio della release e ne controlla l'impronta SHA256. Se
   l'impronta non torna, si ferma e non installa niente.
2. Imposta il fuso orario italiano e gli aggiornamenti di sicurezza
   automatici.
3. Crea l'utente `agente`, senza password e senza poteri di amministratore:
   tu e Claude lavorate con questo utente.
4. Lascia acceso SSH, ma chiuso: si entra solo con una chiave, solo come
   `agente`, e all'inizio `agente` non ha nessuna chiave. Root da SSH non
   entra mai.
5. Installa tmux, git e Claude Code, dal repository firmato di Anthropic, con
   l'aggiornamento automatico spento.
6. Crea `~/boss`, la cartella della prima sessione di Claude, con le sue
   istruzioni in `CLAUDE.md`, e `~/progetti` per le altre.
7. Sulla console entra da solo come `agente` e mostra il promemoria dei
   comandi.

## I comandi del kit

- `salute`: controlla che la macchina sia a posto, una riga per controllo.
- `qr-login`: il login di Claude con il telefono. Mostra un QR, aspetta il
  codice e lo passa a Claude.
- `aiuto`: il promemoria dei comandi.

## Scelte di sicurezza

- L'agente non è amministratore.
- Il firewall del pannello resta senza ingressi: da fuori non si vede nessuna
  porta. Chi vuole usare SSH aggiunge la sua chiave e apre la porta 22 nel
  pannello.
- Il kit non scrive password di root.
- Password, chiavi private e token non passano dalla conversazione con
  Claude.
- Il testo di cloud-init fissa l'impronta dell'archivio: la macchina esegue
  solo la versione provata.

## Se qualcosa non va

- `/var/log/agenti-kit-install.log`: tutto quello che ha fatto
  l'installazione.
- `/var/lib/agenti-kit/stato`: l'esito di ogni passo, `ok` o `da-completare`.
- Da root l'installazione si può rilanciare: `bash /opt/agenti-kit/install.sh`.

## Versioni

Ogni versione è una release con l'archivio e il testo di cloud-init.

- `v0.1`: prima prova su una macchina Hetzner vera. Il kit faceva tutto:
  menu a numeri, sessione di Claude che partiva da sola, SSH spento.
- `v0.2`: il kit ridotto. Escono menu, sessione automatica, Bun e plugin
  Telegram; SSH resta acceso solo con chiave. I pezzi usciti sono in
  `archivio-v0.1/`.

## Per chi sviluppa il kit

- `python3 tools/crea-rilascio.py vX.Y`: archivio, impronta e testo di
  cloud-init in `dist/`.
- `test/prova-docker.sh`: installazione in un contenitore Ubuntu 24.04,
  lanciata due volte, poi i controlli di `test/verifica-installazione.sh`.
- `test/prova-qr-login.sh`: il login con il QR, con un `claude` finto.
