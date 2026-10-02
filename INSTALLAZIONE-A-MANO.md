# Installare il kit a mano

Il modo normale di installare il kit è il cloud-init: incolli un testo
quando crei il server e la macchina fa da sola. Questa pagina serve quando
quella strada non c'è: il fornitore non ha il campo cloud-init, la macchina
esiste già, oppure il cloud-init non è partito.

Ci sono due modi di farlo a mano:

- **Parte A - lanciare tu l'installazione.** Scarichi il kit, controlli che
  sia quello pubblicato e lanci `install.sh`. Sono sei comandi. È la strada
  consigliata: fa esattamente quello che farebbe il cloud-init.
- **Parte B - fare tutto a mano, comando per comando.** Per chi vuole
  sapere cosa succede, o non vuole lanciare uno script da root senza
  averlo letto. È l'elenco di tutto quello che `install.sh` fa, in ordine.

Il kit è provato su **Ubuntu 24.04 e Ubuntu 26.04**. Su altro può
funzionare, ma nessuno l'ha visto.

---

# Parte A - Lanciare l'installazione

## 1. Cosa serve

- Una macchina con **Ubuntu 24.04 o 26.04**, appena creata. Su una macchina
  già usata il kit non cancella niente di tuo, ma cambia SSH (vedi il
  punto 5): leggi tutto prima di cominciare.
- L'accesso come **root**: dalla console del fornitore, oppure in SSH.
- Dieci minuti.

Dove lanciare i comandi: se puoi, **in SSH da root**, perché lì il testo si
incolla. Nella console web di Hetzner il testo incollato arriva rovinato
nei simboli: i comandi qui sotto andrebbero scritti a mano.

## 2. Il firewall, prima di tutto

Nel pannello del fornitore, il firewall della macchina non deve lasciare
entrare niente, a parte la porta che stai usando tu adesso per SSH, se
entri da lì. Una macchina con un indirizzo pubblico e il firewall aperto è
la porta di casa lasciata aperta.

## 3. Scaricare il kit e controllarlo

Apri la pagina delle release,
https://github.com/tommasinigiovanni/alleniamoimprese-agenti-kit/releases,
e prendi la versione più recente che non sia marcata "Pre-release". Nella
sua pagina trovi il numero di versione e l'**impronta dell'archivio**, una
fila di 64 lettere e numeri.

Scrivi la versione in una variabile, così i comandi dopo la usano:

```bash
VERSIONE=v1.6
```

Scarica l'archivio:

```bash
cd /root
curl -fsSL -o kit.tar.gz https://github.com/tommasinigiovanni/alleniamoimprese-agenti-kit/releases/download/$VERSIONE/alleniamoimprese-agenti-kit-$VERSIONE.tar.gz
```

Se `curl` non c'è: `apt-get update` e poi
`apt-get install -y curl ca-certificates`.

Calcola l'impronta di quello che hai scaricato:

```bash
sha256sum kit.tar.gz
```

Confronta la fila che vedi con quella della pagina della release. Devono
essere **uguali, carattere per carattere**. Se non lo sono, fermati:
l'archivio non è quello pubblicato. Cancellalo (`rm kit.tar.gz`) e
riprova il download.

## 4. Installare

Estrai l'archivio e lancia l'installazione:

```bash
rm -rf /opt/agenti-kit
tar -xzf kit.tar.gz -C /opt --no-same-owner
bash /opt/agenti-kit/install.sh
```

Ci mette qualche minuto. Scrive a schermo un passo alla volta. Alla fine
deve dire:

```
=== Installazione completa.
```

Se invece dice "Installazione finita con passi da completare", vai al
punto 8.

Se eri in SSH e la connessione cade durante l'installazione (il kit
sposta SSH sulla porta 2222 proprio in questo passo), non è un guasto:
rientra dalla console web del fornitore e rilancia
`bash /opt/agenti-kit/install.sh`. Riparte da dove serve.

## 5. Subito dopo: la password di agente

**Non chiudere la finestra da root prima di questo passo.** Il kit ha
appena cambiato SSH:

- la porta non è più la 22, è la **2222**;
- **root da SSH non entra più**;
- entra solo `agente`, con la sua password.

La password di `agente` l'ha scelta il kit, a caso, durante
l'installazione. Finché sei root, leggila e annotala:

```bash
cat /home/agente/.password-iniziale
```

È la password con cui entrerai in SSH. La vedi anche nel promemoria, ogni
volta che entri come `agente`, **finché non fai il login di Claude o di
Codex**: in quel momento il file si cancella, perché una password non
resta scritta in chiaro più del necessario.

Se preferisci sceglierla tu, puoi cambiarla subito, sempre da root:

```bash
passwd agente
```

Se l'hai persa non hai perso niente: dalla console web del fornitore
entri come root (`su -`) e lanci `passwd agente`.

## 6. Rientrare come agente

1. Nel firewall del pannello apri in ingresso la porta **TCP 2222**, meglio
   se solo verso il tuo indirizzo IP. Se avevi aperto la 22, richiudila:
   non risponde più nessuno.
2. Dal tuo computer:

```bash
ssh -p 2222 agente@INDIRIZZO-DELLA-MACCHINA
```

3. Controlla la macchina:

```bash
salute
```

Deve dire `[OK]` su tutto tranne due righe, che sono giuste così: il login
di Claude e il boss, che non hai ancora fatto.

## 7. Il login e il boss

Da qui in poi è uguale a chi ha usato il cloud-init:

```bash
qr-login-claude
tmux new -s boss
cd boss
claude -n boss --rc
```

`aiuto` rivede il promemoria dei comandi. Per uscire da tmux lasciando
tutto acceso: Ctrl+B, poi D.

## 8. Se qualcosa non va

- **"install.sh va lanciato come root".** Non sei root: `su -` dalla
  console, oppure `sudo -i` se il tuo utente può.
- **L'installazione finisce con passi da completare.** Il nome dei passi è
  scritto in fondo, e in `/var/lib/agenti-kit/stato`. Il dettaglio è in
  `/var/log/agenti-kit-install.log`: cerca le righe che cominciano con
  `!!!`. Quasi sempre è la rete che è caduta durante un download:
  rilancia `bash /opt/agenti-kit/install.sh`. Si può rilanciare quante
  volte vuoi: ogni passo controlla cosa c'è già, e la password di `agente`
  non cambia.
- **Il passo `ssh` resta da completare.** Vuol dire che SSH non ascolta
  sulla 2222. Guarda `ss -ltn` e le ultime righe del registro, e scrivilo
  nello spogliatoio con quello che vedi.
- **Non riesci più a entrare in SSH.** La console web del fornitore
  funziona sempre: entri da lì come `agente` senza password, o come root
  con la sua. Controlla nell'ordine: stai usando la password giusta? La
  2222 è aperta nel firewall? Stai usando `-p 2222`?

---

# Parte B - Tutto a mano, comando per comando

Questo è l'elenco di quello che fa `install.sh`, nello stesso ordine, come
comandi da lanciare **da root**. Segue la versione `v1.6` del kit: se un
giorno questo elenco e `install.sh` dicessero cose diverse, vale
`install.sh`.

Due avvisi prima di cominciare.

- I file del kit servono lo stesso: i comandi (`salute`, `installa`, i due
  login, `aiuto`), le istruzioni del boss, le regole della macchina e il
  profilo della console sono file, non comandi. Scarica e controlla l'archivio come al punto 3 della
  Parte A ed estrailo in `/opt/agenti-kit`. La differenza è che
  `install.sh` non lo lanci.
- `install.sh` dopo ogni passo controlla che sia andato. Qui il controllo
  lo fai tu: dopo ogni blocco c'è scritto cosa guardare.

## B1. I programmi di base, il fuso orario, gli aggiornamenti

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y tmux git qrencode jq unzip curl ca-certificates gnupg tzdata unattended-upgrades iproute2 openssh-server sudo python3-venv kbd console-setup keyboard-configuration syncthing procps
timedatectl set-timezone Europe/Rome
printf '%s\n' 'APT::Periodic::Update-Package-Lists "1";' 'APT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades
```

Da guardare: `date` dà l'ora italiana.

## B2. L'utente agente, amministratore

```bash
useradd -m -s /bin/bash agente
usermod -aG sudo agente
printf '%s\n' 'agente ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/agenti-kit
chmod 440 /etc/sudoers.d/agenti-kit
visudo -cf /etc/sudoers.d/agenti-kit
```

`agente` usa `sudo` senza password, e Claude gira come `agente`: quindi
anche Claude. Il guardrail non è qui, è la regola di Claude Code del
punto B8, che fa chiedere conferma a ogni comando `sudo`. Se vuoi una
macchina dove Claude **non** è amministratore, salta la riga con
`printf`: `sudo` chiederà la password di `agente`, che Claude non ha.

Da guardare: `visudo` risponde `parsed OK`. Se dà un errore, **cancella
subito il file** (`rm /etc/sudoers.d/agenti-kit`): un file di regole
sbagliato può bloccare `sudo` per tutti.

## B3. La password di agente

Il kit ne genera una a caso e la scrive in un file che legge solo `agente`:

```bash
P=$(LC_ALL=C tr -dc 'abcdefghjkmnpqrstuvwxyz23456789' < /dev/urandom | head -c 16)
P="${P:0:4}-${P:4:4}-${P:8:4}-${P:12:4}"
printf 'agente:%s\n' "$P" | chpasswd
( umask 077; printf '%s\n' "$P" > /home/agente/.password-iniziale )
chown agente:agente /home/agente/.password-iniziale
chmod 600 /home/agente/.password-iniziale
unset P
```

Oppure la scegli tu, e il file non serve: `passwd agente`.

Da guardare: `passwd -S agente` ha una `P` come seconda parola.

## B4. La console: tastiera italiana e carattere del QR

```bash
sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="it"/; s/^XKBVARIANT=.*/XKBVARIANT=""/' /etc/default/keyboard
sed -i 's/^CHARMAP=.*/CHARMAP="UTF-8"/; s/^CODESET=.*/CODESET="Uni2"/; s/^FONTFACE=.*/FONTFACE="VGA"/; s/^FONTSIZE=.*/FONTSIZE="8x14"/' /etc/default/console-setup
setupcon --save-only
setupcon --force
```

Da guardare: nella console web un QR disegnato con `qrencode -t UTF8 prova`
ha i quadratini pieni, non dei cancelletti.

## B5. SSH: porta 2222, password, solo agente

```bash
cat > /etc/ssh/sshd_config.d/00-agenti-kit.conf <<'FINE'
Port 2222
PasswordAuthentication yes
PermitEmptyPasswords no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers agente
FINE
chmod 644 /etc/ssh/sshd_config.d/00-agenti-kit.conf
mkdir -p /run/sshd
sshd -t
systemctl stop ssh.service ssh.socket
systemctl daemon-reload
systemctl enable --now ssh.socket
```

Il nome del file comincia con `00` perché in SSH vale il primo valore
letto. Se la tua macchina non ha `ssh.socket` (lo dice
`systemctl list-unit-files ssh.socket`), al posto delle ultime tre righe:
`systemctl daemon-reload` e `systemctl restart ssh.service`.

Da guardare: `ss -ltn` mostra una riga con `:2222` e nessuna con `:22`.
Se sei collegato in SSH da root, da questo momento non puoi più rientrare
così: vedi il punto 5 della Parte A.

## B6. Claude Code, dal repository firmato di Anthropic

```bash
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o /etc/apt/keyrings/claude-code.asc
gpg --show-keys --with-colons /etc/apt/keyrings/claude-code.asc | awk -F: '/^fpr/ {print $10; exit}'
```

L'ultima riga stampa l'impronta della chiave. Deve essere
`31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`, quella pubblicata da Anthropic
nella documentazione di installazione. Se è diversa, fermati e cancella
il file.

```bash
echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" > /etc/apt/sources.list.d/claude-code.list
apt-get update
apt-get install -y --allow-downgrades claude-code=2.1.280-1
apt-mark hold claude-code
```

La versione è quella con cui il corso è stato provato, e `hold` la blocca.

Da guardare: `claude --version` risponde `2.1.280`.

## B7. Codex, come pacchetto completo

Su una macchina x86 (le CX e CPX di Hetzner):

```bash
curl -fsSL -o /tmp/codex.tar.gz https://github.com/openai/codex/releases/download/rust-v0.159.2/codex-package-x86_64-unknown-linux-musl.tar.gz
echo "9e2d29a713b94478b240dec2f10e11324cd05fad76dc43e7c639bdf8a1337a6b  /tmp/codex.tar.gz" | sha256sum -c -
```

Su una macchina ARM (le CAX), cambiano il nome e l'impronta:
`codex-package-aarch64-unknown-linux-musl.tar.gz` e
`05a524a463cadf7e3e22c7f923539c0d0b74c3e78b1f5f1fab52e50e6fb3312f`.

Se `sha256sum` non risponde `OK`, fermati. Poi:

```bash
install -d -m 755 -o root -g root /opt/codex-0.159.2
tar -xzf /tmp/codex.tar.gz -C /opt/codex-0.159.2 --no-same-owner
chown -R root:root /opt/codex-0.159.2
chmod -R go-w /opt/codex-0.159.2
ln -sf /opt/codex-0.159.2/bin/codex /usr/local/bin/codex
rm /tmp/codex.tar.gz
```

Da guardare: `codex --version` risponde `codex-cli 0.159.2`.

## B8. Le cartelle e i file di agente

```bash
install -d -o agente -g agente -m 700 /home/agente/.claude /home/agente/.cache /home/agente/boss /home/agente/progetti /home/agente/segreti
chmod 700 /home/agente
echo '{}' > /home/agente/.claude/settings.json
jq '.env.DISABLE_AUTOUPDATER = "1" | .permissions.ask = ["Bash(sudo:*)"]' /home/agente/.claude/settings.json > /tmp/s.json && mv /tmp/s.json /home/agente/.claude/settings.json
jq -n --arg v "$(claude --version | awk '{print $1}')" '{hasCompletedOnboarding: true, lastOnboardingVersion: $v, theme: "dark", projects: {"/home/agente/boss": {hasTrustDialogAccepted: true}}}' > /home/agente/.claude.json
chmod 600 /home/agente/.claude.json
install -m 600 /opt/agenti-kit/boss/CLAUDE.md /opt/agenti-kit/boss/AGENTS.md /home/agente/boss/
install -d -o agente -g agente -m 700 /home/agente/.codex
install -m 600 /opt/agenti-kit/macchina/ISTRUZIONI.md /home/agente/.claude/CLAUDE.md
install -m 600 /opt/agenti-kit/macchina/ISTRUZIONI.md /home/agente/.codex/AGENTS.md
printf '%s\n' 'set -g prefix2 C-a' 'set -g focus-events on' 'set -g history-limit 10000' > /home/agente/.tmux.conf
echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/agente/.profile
echo 'umask 077' >> /home/agente/.profile
chown -R agente:agente /home/agente/.claude /home/agente/.codex /home/agente/.claude.json /home/agente/boss /home/agente/progetti /home/agente/segreti /home/agente/.profile /home/agente/.tmux.conf
```

Cosa sono: `boss` è la cartella della prima sessione, con le sue
istruzioni; `progetti` quella delle altre; `segreti` è dove stanno
password e token, un file per servizio. I due file `ISTRUZIONI.md`
copiati sono le regole della macchina: le legge ogni sessione, Claude da
`~/.claude/CLAUDE.md` e Codex da `~/.codex/AGENTS.md`. Le due righe con `jq` spengono
l'aggiornamento automatico di Claude, gli fanno **chiedere conferma a ogni
comando `sudo`** (è il guardrail del punto B2: non saltarla) e saltano le
domande del primo avvio, solo per la cartella del boss.

Da guardare: `ls -la /home/agente` mostra le cartelle, tutte di `agente`.

## B9. Syncthing, pronto e spento

```bash
runuser -l agente -c 'syncthing generate --no-default-folder'
sed -i 's|<urAccepted>[^<]*</urAccepted>|<urAccepted>-1</urAccepted>|; s|<crashReportingEnabled>[^<]*</crashReportingEnabled>|<crashReportingEnabled>false</crashReportingEnabled>|' /home/agente/.local/state/syncthing/config.xml
chown -R agente:agente /home/agente/.local
```

Crea l'identità della macchina e spegne le segnalazioni automatiche.
Syncthing resta spento: lo accende il boss quando gli chiedi di collegare
una cartella.

Da guardare: `grep 127.0.0.1:8384 /home/agente/.local/state/syncthing/config.xml`
trova una riga. L'interfaccia di Syncthing deve restare sulla sola
macchina.

## B10. I comandi del kit

```bash
install -m 755 -o root -g root /opt/agenti-kit/bin/* /usr/local/bin/
install -d -m 755 /usr/local/share/agenti-kit
install -m 644 /opt/agenti-kit/VERSIONE /usr/local/share/agenti-kit/
```

Da guardare: `ls -l /usr/local/bin/installa` dice `root root` e
`-rwxr-xr-x`. E `runuser -u agente -- sudo -n -l /usr/local/bin/installa`
risponde con il percorso del comando.

## B11. Le sessioni che restano accese, e la console

```bash
loginctl enable-linger agente
install -m 644 -o agente -g agente /opt/agenti-kit/console/bash_profile /home/agente/.bash_profile
install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/agenti-kit.conf <<'FINE'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin agente --noclear %I $TERM
FINE
systemctl daemon-reload
systemctl restart getty@tty1.service
```

Il `linger` tiene accese le sessioni di tmux anche quando sulla console
non c'è nessuno. L'ultima parte fa entrare la console web direttamente
come `agente`, con il promemoria.

Da guardare: nella console web del fornitore compare il promemoria "La
tua macchina".

## B12. Il controllo finale

Entra come `agente` (dalla console web, o in SSH sulla 2222) e lancia:

```bash
salute
```

La prima riga dirà `[DA FARE] Installazione: non risulta fatta`: è giusto,
perché il file di stato lo scrive solo `install.sh`. Se hai fatto tutti i
passi e vuoi che `salute` lo sappia, da root:

```bash
install -d /var/lib/agenti-kit
echo "a-mano ok" > /var/lib/agenti-kit/stato
```

Tutto il resto deve essere `[OK]`, tranne il login e il boss, che fai
adesso come al punto 7 della Parte A.
