# Il kit della macchina: Agenti che non dormono

Il kit che prepara la macchina del corso "Agenti che non dormono" di
AlleniamoImprese. Non si installa a mano: quando crei il server su Hetzner
incolli nel campo cloud-init il testo della release, e la macchina fa da sola.

Il kit fa solo il pavimento. tmux, Claude e Remote Control li accendi tu: è
quello che si impara nel corso.

Se non puoi usare il cloud-init (il fornitore non ha quel campo, o la
macchina esiste già), i passi da fare a mano sono in
[INSTALLAZIONE-A-MANO.md](INSTALLAZIONE-A-MANO.md): come lanciare tu
l'installazione, e l'elenco di tutti i comandi per chi vuole fare ogni
passo da sé.

## Su cosa gira

**Ubuntu 24.04 e Ubuntu 26.04**, su macchine x86 e ARM. Sono le due
versioni su cui il kit è provato a ogni modifica. Le differenze fra le due
che il kit conosce: sulla 26.04 `sudo` è `sudo-rs` e Python è il 3.14. Su
altre versioni o altre distribuzioni può funzionare, ma nessuno l'ha visto.

## Cosa fa

Alla prima accensione, come root:

1. Scarica l'archivio della release e ne controlla l'impronta SHA256. Se
   l'impronta non torna, si ferma e non installa niente.
2. Imposta il fuso orario italiano e gli aggiornamenti di sicurezza
   automatici.
3. Imposta la console: tastiera italiana, e un carattere che sa disegnare il
   QR del login.
4. Crea l'utente `agente`: tu e Claude lavorate con questo utente. Gli dà
   una password a caso e te la mostra nel promemoria, finché non fai il
   login di Claude o di Codex: annotala, poi sparisce. La puoi cambiare
   con `passwd`. Con la sua password `agente`
   diventa amministratore via `sudo`; Claude, che non ha un terminale e
   non conosce la password, no. L'unica cosa che passa senza password è
   `installa NOME`, che mette pacchetti di Ubuntu e non accetta altro: così
   Claude installa da solo quello che serve a un progetto. Installa anche
   `python3-venv`, per i programmi Python con le loro librerie.
5. Lascia acceso SSH sulla porta 2222, con la password, solo come `agente`.
   Root da SSH non entra mai. Da fuori la porta non si vede finché non la
   apri nel firewall del pannello. Crea `~/segreti`, la cartella dove
   scrivi password e token: un file per servizio, leggibile solo da te.
6. Installa tmux, git e Claude Code, dal repository firmato di Anthropic, alla
   versione con cui il corso è stato provato, con l'aggiornamento automatico
   spento. Installa anche Codex, dalla release di
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
- `qr-login-claude`: il login di Claude. Mostra un QR e sotto l'indirizzo per
  intero, aspetta il codice e lo passa a Claude. Il QR si inquadra con il
  telefono, oppure si fotografa dal computer e si apre con la pagina
  https://claude.ai/artifact/GTNLnb5i1Xqi7F9bD16q9U, che prepara anche il
  codice da incollare.
- `qr-login-codex`: il login di Codex con il telefono. Mostra un QR, un
  indirizzo corto e un codice da scrivere nella pagina.
- `installa NOME`: installa pacchetti di Ubuntu, senza password. Solo nomi
  di pacchetti, niente opzioni. Lo usa anche Claude.
- `aiuto`: il promemoria dei comandi.

## Scelte di sicurezza

- Claude non è amministratore. `agente` lo diventa solo con la sua
  password, da un terminale: `sudo` senza password non passa, e il
  permesso vale solo sul terminale che l'ha data, per cinque minuti.
  L'unica eccezione è `installa`, che mette pacchetti di Ubuntu e basta:
  è di root, non si può cambiare, e rifiuta tutto quello che non è un
  nome di pacchetto.
- Il firewall del pannello resta senza ingressi: da fuori non si vede nessuna
  porta. Chi vuole usare SSH dà una password ad `agente` e apre la porta
  2222 nel pannello, meglio se solo verso il proprio indirizzo. La 2222 al
  posto della 22 toglie il rumore dei robot, non il rischio: quello lo tiene
  fuori il firewall.
- Il kit non scrive la password di root. Ad `agente` ne dà una a caso,
  generata sulla macchina: non sta nel testo di cloud-init né nei
  registri. Sta in un file che legge solo `agente`, e il file si cancella
  quando riesce il login di Claude o di Codex, perché da lì in poi sulla
  macchina c'è un'AI che gira come `agente` e che la password non la deve
  leggere.
- Password, chiavi private e token non passano dalla conversazione con
  Claude: stanno in `~/segreti`, un file per servizio.
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
- `v0.4.1`: Codex installato come pacchetto completo: il solo programma si
  fermava alla prima sessione. QR con il bordo più largo, leggibile anche da
  una foto dello schermo.
- `v0.4.2`: `qr-login-claude` accetta il codice del login trasformato in sole
  lettere e numeri dalla pagina "Login senza telefono": incollato così com'è,
  in console arrivava rovinato.
- `v0.4.3`: le sessioni hanno un nome. Il boss si lancia con
  `claude -n boss --rc` e si riprende con `claude -r boss --rc`; le sessioni
  di progetto che apre il boss prendono il nome del progetto.
- `v1.0`: il kit congelato per l'edizione che parte il 5 ottobre 2026. È la
  `v0.4.3` con la versione di Claude Code fissata a quella provata (2.1.280).
  È la versione che usano gli studenti.
- `v1.1`: SSH sulla porta 2222 con la password di `agente`, al posto della
  sola chiave: da Windows basta PowerShell, senza chiavi da spostare. Root
  da SSH resta fuori. C'è `~/segreti`, la cartella per password e token.
  Il resto è la `v1.0`.
- `v1.2`: `agente` può usare `sudo` con la sua password (Claude no: non ha
  un terminale e non la conosce), e c'è `python3-venv`. Nata dalla prova
  della plancia: per installarla serviva un pacchetto di sistema.
- `v1.3`: `installa NOME`, l'unico comando da amministratore senza
  password: pacchetti di Ubuntu e basta, così Claude installa da solo
  quello che serve a un progetto. Il boss sa tenere acceso un programma
  come servizio dell'utente e dice quale porta aprire nel firewall.
- `v1.4`: compatibile con Ubuntu 26.04 oltre che con la 24.04 (le regole
  di `sudo` si adattano a `sudo-rs`), e `agente` nasce con una password a
  caso, mostrata nel promemoria fino al primo login di un'AI. Il passo
  `su -` e `passwd agente` non serve più. C'è
  [INSTALLAZIONE-A-MANO.md](INSTALLAZIONE-A-MANO.md).

## Per chi sviluppa il kit

- `python3 tools/crea-rilascio.py vX.Y`: archivio, impronta e testo di
  cloud-init in `dist/`.
- `test/prova-docker.sh [piattaforma] [immagine]`: installazione in un
  contenitore Ubuntu (di base `ubuntu:24.04`, si prova anche con
  `ubuntu:26.04`), lanciata due volte, poi i controlli di
  `test/verifica-installazione.sh`.
- `test/prova-qr-login.sh` e `test/prova-qr-login-codex.sh`: i due login con
  il QR, con un `claude` e un `codex` finti.
