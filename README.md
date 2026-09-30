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
3. Imposta la console: tastiera italiana, e un carattere che sa disegnare il
   QR del login.
4. Crea l'utente `agente`, senza password e senza poteri di amministratore:
   tu e Claude lavorate con questo utente.
5. Lascia acceso SSH, ma chiuso: si entra solo con una chiave, solo come
   `agente`, e all'inizio `agente` non ha nessuna chiave. Root da SSH non
   entra mai.
6. Installa tmux, git e Claude Code, dal repository firmato di Anthropic, con
   l'aggiornamento automatico spento. Installa anche Codex, dalla release di
   OpenAI su GitHub, a versione fissata e con l'impronta controllata.
7. Installa Syncthing e lo lascia spento: serve a tenere uguale una cartella
   fra la macchina e il tuo computer, senza servizi in mezzo.
8. Crea `~/boss`, la cartella della prima sessione, con le sue istruzioni:
   `CLAUDE.md` per Claude e `AGENTS.md` per Codex. E `~/progetti` per le
   altre sessioni.
9. Sulla console entra da solo come `agente` e mostra il promemoria dei
   comandi.

## I comandi del kit

- `salute`: controlla che la macchina sia a posto, una riga per controllo.
- `qr-login-claude`: il login di Claude con il telefono. Mostra un QR e
  sotto l'indirizzo per intero, aspetta il codice e lo passa a Claude.
- `qr-login-codex`: il login di Codex con il telefono. Mostra un QR, un
  indirizzo corto e un codice da scrivere nella pagina.
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
- `v0.2.1`: dalla prova sulla console di Hetzner. Tastiera italiana, carattere
  della console con i mezzi blocchi, QR senza colori con l'indirizzo sotto,
  niente `~` nei comandi da scrivere.
- `v0.3`: c'è anche Codex. `qr-login` diventa `qr-login-claude`, e arriva
  `qr-login-codex`.
- `v0.3.1`: si può seguire anche con il solo Codex. `salute` chiede un login,
  di Claude o di Codex; il boss ha le istruzioni anche per Codex.
- `v0.4`: c'è Syncthing, spento. Il boss sa collegare una cartella della
  macchina al computer dello studente.

## Per chi sviluppa il kit

- `python3 tools/crea-rilascio.py vX.Y`: archivio, impronta e testo di
  cloud-init in `dist/`.
- `test/prova-docker.sh`: installazione in un contenitore Ubuntu 24.04,
  lanciata due volte, poi i controlli di `test/verifica-installazione.sh`.
- `test/prova-qr-login.sh` e `test/prova-qr-login-codex.sh`: i due login con
  il QR, con un `claude` e un `codex` finti.
