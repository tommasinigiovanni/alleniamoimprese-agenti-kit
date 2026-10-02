#!/usr/bin/env bash
# Prepara la macchina del corso "Agenti che non dormono".
#
# Gira come root, una volta, lanciato da cloud-init. Si può rilanciare a mano:
# ogni passo controlla cosa c'è già e non rompe quello che trova.
# Il registro è in /var/log/agenti-kit-install.log, l'esito di ogni passo in
# /var/lib/agenti-kit/stato.
#
# AGENTI_SENZA_SYSTEMD=1 salta systemd, linger e console: serve solo per le
# prove in un contenitore.

set -uo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTENTE=agente
CASA="/home/$UTENTE"
STATO_DIR=/var/lib/agenti-kit
STATO="$STATO_DIR/stato"
REGISTRO=/var/log/agenti-kit-install.log
SENZA_SYSTEMD="${AGENTI_SENZA_SYSTEMD:-0}"
# Impronta della chiave di firma di Claude Code, pubblicata da Anthropic nella
# documentazione di installazione (code.claude.com/docs/en/setup).
IMPRONTA_CHIAVE_CLAUDE="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
# La versione di Claude Code con cui il corso è stato provato. Il repository
# di Anthropic tiene anche le versioni vecchie: si installa questa, e la si
# blocca, così la macchina di ogni studente è uguale a quella provata.
VERSIONE_CLAUDE="2.1.280-1"
# Nei primi minuti di una macchina nuova gli aggiornamenti automatici di Ubuntu
# tengono occupato apt: si aspetta che lo liberino, fino a dieci minuti.
APT=(apt-get -o DPkg::Lock::Timeout=600)

# Codex si scarica dalla release di OpenAI su GitHub, a versione fissata, e si
# installa solo se l'impronta dell'archivio è quella attesa. Le impronte sono
# quelle del pacchetto completo (codex-package-...), non del solo programma.
VERSIONE_CODEX="0.159.2"
IMPRONTA_CODEX_X86="9e2d29a713b94478b240dec2f10e11324cd05fad76dc43e7c639bdf8a1337a6b"
IMPRONTA_CODEX_ARM="05a524a463cadf7e3e22c7f923539c0d0b74c3e78b1f5f1fab52e50e6fb3312f"

if [ "$(id -u)" -ne 0 ]; then
  echo "install.sh va lanciato come root."
  exit 1
fi

mkdir -p "$STATO_DIR"
: > "$STATO"
exec > >(tee -a "$REGISTRO") 2>&1
echo "=== Installazione del kit $(cat "$KIT_DIR/VERSIONE" 2>/dev/null || echo 'di sviluppo'), $(date -Is)"

# passo NOME FUNZIONE: esegue la funzione e ne segna l'esito nel file di stato.
passo() {
  local nome="$1"
  shift
  echo "--- $nome"
  if "$@"; then
    echo "$nome ok" >> "$STATO"
  else
    echo "$nome da-completare" >> "$STATO"
    echo "!!! $nome non completato: vedi sopra."
  fi
}

# Ripete un comando fino a tre volte: la rete a volte cade proprio adesso.
riprova() {
  local tentativo
  for tentativo in 1 2 3; do
    "$@" && return 0
    echo "Tentativo $tentativo non riuscito: riprovo fra 10 secondi."
    sleep 10
  done
  return 1
}

sistema_base() {
  export DEBIAN_FRONTEND=noninteractive
  riprova "${APT[@]}" update -q || return 1
  # python3-venv serve ai programmi Python con le loro librerie (la plancia).
  riprova "${APT[@]}" install -y -q tmux git qrencode jq unzip curl ca-certificates \
    gnupg tzdata unattended-upgrades iproute2 openssh-server sudo python3-venv \
    kbd console-setup keyboard-configuration syncthing procps || return 1
  if ! timedatectl set-timezone Europe/Rome 2>/dev/null; then
    ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
    echo Europe/Rome > /etc/timezone
  fi
  printf '%s\n' 'APT::Periodic::Update-Package-Lists "1";' \
    'APT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades
}

utente_agente() {
  if ! id "$UTENTE" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$UTENTE" || return 1
  fi
  # La password di agente la dà il passo dopo (password_agente).
  #
  # agente diventa amministratore con la sua password, via sudo: lo studente
  # da SSH scrive "sudo ..." e la password. Claude, che gira come agente ma
  # non ha un terminale e non conosce la password, non può. Il permesso vale
  # solo sul terminale che ha dato la password (tty), così una shell di
  # Claude non lo eredita, e dura cinque minuti.
  # Un'eccezione sola, senza password: "installa", che mette pacchetti di
  # Ubuntu e non accetta altro. Così Claude installa da solo quello che serve
  # a un progetto, e non tocca il resto del sistema.
  usermod -aG sudo "$UTENTE" || return 1
  # Ubuntu 24.04 ha il sudo di sempre, la 26.04 ha sudo-rs, che non conosce
  # timestamp_type (lì il permesso è già legato al terminale, di serie). Si
  # scrive la versione più completa che il sudo di questa macchina accetta:
  # la regola di "installa" c'è in tutte.
  local regole=/etc/sudoers.d/agenti-kit predefiniti
  for predefiniti in 'Defaults:agente timestamp_type=tty, timestamp_timeout=5, passwd_tries=3' \
                     'Defaults:agente timestamp_timeout=5, passwd_tries=3' \
                     '# (nessuna impostazione in più: questo sudo non le accetta)'; do
    printf '%s\n' '# Kit del corso "Agenti che non dormono": sudo ad agente con la sua password,' \
      '# e "installa" (solo pacchetti di Ubuntu) senza.' "$predefiniti" \
      'agente ALL=(root) NOPASSWD: /usr/local/bin/installa' > "$regole"
    chmod 440 "$regole"
    visudo -cf "$regole" >/dev/null 2>&1 && break
    rm -f "$regole"
  done
  [ -f "$regole" ] || { echo "Le regole di sudo del kit non passano il controllo."; return 1; }
  id -nG "$UTENTE" | tr ' ' '\n' | grep -qx sudo || return 1
  # Senza password sudo non deve passare: è la garanzia che Claude resta fuori.
  ! runuser -u "$UTENTE" -- sudo -n true >/dev/null 2>&1
}

# agente nasce con una password a caso, che serve per SSH e per sudo. Il kit
# non la conserva: la scrive in un file che legge solo agente, il promemoria
# la mostra, e il file sparisce quando riesce il login di Claude o di Codex,
# perché da lì in poi sulla macchina c'è un'AI che gira come agente e che la
# password non la deve avere. Non passa dal testo di cloud-init né dai
# registri. Se agente ha già una password (l'ha scelta lo studente, o
# install.sh gira di nuovo) non si tocca.
password_agente() {
  local file="$CASA/.password-iniziale" password
  [ "$(passwd -S "$UTENTE" 2>/dev/null | awk '{print $2}')" = P ] && return 0
  # Niente lettere e cifre che si confondono a occhio: 0 e o, 1 e l e i.
  password="$(LC_ALL=C tr -dc 'abcdefghjkmnpqrstuvwxyz23456789' < /dev/urandom | head -c 16)"
  [ "${#password}" -eq 16 ] || return 1
  password="${password:0:4}-${password:4:4}-${password:8:4}-${password:12:4}"
  printf '%s:%s\n' "$UTENTE" "$password" | chpasswd || return 1
  ( umask 077; printf '%s\n' "$password" > "$file" ) || return 1
  chown "$UTENTE:$UTENTE" "$file" && chmod 600 "$file" || return 1
  [ "$(passwd -S "$UTENTE" | awk '{print $2}')" = P ]
}

# "installa" passa da sudo senza password: deve essere di root e non
# scrivibile da altri, se no agente potrebbe cambiarlo e farci passare altro.
# I comandi del kit vengono copiati dopo (passo "comandi"): qui si controlla.
installa_senza_password() {
  [ -x /usr/local/bin/installa ] || return 1
  [ "$(stat -c %U:%a /usr/local/bin/installa)" = root:755 ] || return 1
  runuser -u "$UTENTE" -- sudo -n -l /usr/local/bin/installa >/dev/null 2>&1 || return 1
  # Un'opzione mascherata da pacchetto non deve passare.
  ! runuser -u "$UTENTE" -- /usr/local/bin/installa -- --dangerous >/dev/null 2>&1
}

# La console del pannello manda i tasti come li manda la tastiera: senza
# questo passo una tastiera italiana scrive i simboli di quella americana.
# Il carattere di serie non ha i mezzi blocchi con cui si disegna il QR del
# login: VGA 8x14 li ha. Provato sulla console di Hetzner il 29 settembre 2026.
console_italiana() {
  local tastiera=/etc/default/keyboard schermo=/etc/default/console-setup
  [ -f "$tastiera" ] || printf '%s\n' 'XKBMODEL="pc105"' 'XKBLAYOUT="us"' \
    'XKBVARIANT=""' 'XKBOPTIONS=""' 'BACKSPACE="guess"' > "$tastiera"
  sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="it"/; s/^XKBVARIANT=.*/XKBVARIANT=""/' "$tastiera" || return 1
  grep -qx 'XKBLAYOUT="it"' "$tastiera" || return 1
  [ -f "$schermo" ] || printf '%s\n' 'ACTIVE_CONSOLES="/dev/tty[1-6]"' 'CHARMAP="UTF-8"' \
    'CODESET="Uni2"' 'FONTFACE="VGA"' 'FONTSIZE="8x14"' > "$schermo"
  sed -i 's/^CHARMAP=.*/CHARMAP="UTF-8"/; s/^CODESET=.*/CODESET="Uni2"/;
          s/^FONTFACE=.*/FONTFACE="VGA"/; s/^FONTSIZE=.*/FONTSIZE="8x14"/' "$schermo" || return 1
  grep -qx 'FONTFACE="VGA"' "$schermo" && grep -qx 'FONTSIZE="8x14"' "$schermo" || return 1
  [ -f /usr/share/consolefonts/Uni2-VGA14.psf.gz ] || return 1
  # Salva per i prossimi avvii; poi applica subito, se una console c'è.
  setupcon --save-only >/dev/null 2>&1 || true
  [ "$SENZA_SYSTEMD" = 1 ] && return 0
  setupcon --force >/dev/null 2>&1 || true
}

# SSH acceso sulla porta 2222, con la password: entra solo agente, con la
# password che il kit gli ha dato (o con quella che lo studente ha scelto).
# Root da SSH non entra mai, e una password vuota non vale. Da fuori la porta
# non si vede finché lo studente non la apre nel firewall del pannello.
# La 2222 al posto della 22 toglie il rumore dei robot che provano le password
# su tutta la rete: non è una protezione, quella è il firewall.
# Il nome comincia con 00: in sshd vale il primo valore letto, e cloud-init
# scrive il suo file (50-cloud-init.conf) dopo.
ssh_con_password() {
  install -d -m 755 /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/00-agenti-kit.conf <<'FINE'
# Kit del corso "Agenti che non dormono".
Port 2222
PasswordAuthentication yes
PermitEmptyPasswords no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers agente
FINE
  chmod 644 /etc/ssh/sshd_config.d/00-agenti-kit.conf
  if ! grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config; then
    echo "sshd_config non legge la cartella sshd_config.d: mi fermo."
    return 1
  fi
  mkdir -p /run/sshd
  sshd -t || return 1
  local valori
  valori="$(sshd -T 2>/dev/null)"
  printf '%s\n' "$valori" | grep -qx 'port 2222' || return 1
  printf '%s\n' "$valori" | grep -qx 'passwordauthentication yes' || return 1
  printf '%s\n' "$valori" | grep -qx 'permitemptypasswords no' || return 1
  printf '%s\n' "$valori" | grep -qx 'permitrootlogin no' || return 1
  printf '%s\n' "$valori" | grep -qx 'allowusers agente' || return 1
  [ "$SENZA_SYSTEMD" = 1 ] && return 0
  local unita
  for unita in ssh.socket ssh.service; do
    systemctl unmask "$unita" >/dev/null 2>&1 || true
  done
  # Su Ubuntu 24.04 il server parte dal socket, alla prima connessione, e il
  # socket prende la porta da sshd_config (sshd-socket-generator). Il socket
  # non si riavvia finché il servizio è acceso: prima si spegne tutto.
  if systemctl list-unit-files ssh.socket >/dev/null 2>&1; then
    systemctl stop ssh.service ssh.socket >/dev/null 2>&1 || true
    systemctl daemon-reload
    systemctl enable --now ssh.socket >/dev/null 2>&1 || return 1
  else
    systemctl daemon-reload
    systemctl enable ssh.service >/dev/null 2>&1 || return 1
    systemctl restart ssh.service >/dev/null 2>&1 || return 1
  fi
  # Si guarda il risultato, non la configurazione: 2222 in ascolto, 22 no.
  local ascolto
  ascolto="$(ss -H -ltn 2>/dev/null | awk '{print $4}')"
  printf '%s\n' "$ascolto" | grep -qE ':2222$' || { echo "SSH non ascolta sulla 2222."; return 1; }
  ! printf '%s\n' "$ascolto" | grep -qE ':22$' || { echo "SSH ascolta ancora sulla 22."; return 1; }
}

claude_code() {
  install -d -m 0755 /etc/apt/keyrings
  riprova curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
    -o /etc/apt/keyrings/claude-code.asc || return 1
  local impronta
  impronta="$(GNUPGHOME="$(mktemp -d)" gpg --show-keys --with-colons \
    /etc/apt/keyrings/claude-code.asc 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')"
  if [ "$impronta" != "$IMPRONTA_CHIAVE_CLAUDE" ]; then
    echo "La chiave scaricata non è quella di Anthropic: mi fermo."
    rm -f /etc/apt/keyrings/claude-code.asc
    return 1
  fi
  echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
    > /etc/apt/sources.list.d/claude-code.list
  riprova "${APT[@]}" update -q || return 1
  # La si sblocca prima di installare: serve quando install.sh gira di nuovo.
  apt-mark unhold claude-code >/dev/null 2>&1 || true
  if ! DEBIAN_FRONTEND=noninteractive riprova "${APT[@]}" install -y -q --allow-downgrades \
      "claude-code=$VERSIONE_CLAUDE"; then
    # Meglio una macchina che funziona con una versione più nuova che una
    # macchina senza Claude: si prende l'ultima, e resta scritto nel registro.
    echo "!!! La versione $VERSIONE_CLAUDE di Claude Code non si installa: prendo l'ultima."
    DEBIAN_FRONTEND=noninteractive riprova "${APT[@]}" install -y -q claude-code || return 1
  fi
  apt-mark hold claude-code >/dev/null 2>&1 || true
  command -v claude >/dev/null
}

# Codex va installato come pacchetto completo: il solo programma parte, ma
# alla prima sessione si ferma con "this CLI has no complete local package".
# Il pacchetto sta in /opt, di root; in /usr/local/bin c'è il collegamento.
codex_cli() {
  local architettura impronta nome temporanea destinazione
  case "$(uname -m)" in
    x86_64) architettura=x86_64; impronta="$IMPRONTA_CODEX_X86" ;;
    aarch64 | arm64) architettura=aarch64; impronta="$IMPRONTA_CODEX_ARM" ;;
    *) echo "Codex non ha una versione per questa macchina ($(uname -m))."; return 1 ;;
  esac
  destinazione="/opt/codex-$VERSIONE_CODEX"
  if [ -x "$destinazione/bin/codex" ] && [ -f "$destinazione/codex-package.json" ] &&
     [ "$(readlink -f /usr/local/bin/codex)" = "$destinazione/bin/codex" ]; then
    return 0
  fi
  nome="codex-package-$architettura-unknown-linux-musl"
  temporanea="$(mktemp -d)" || return 1
  if ! riprova curl -fsSL --max-time 900 -o "$temporanea/codex.tar.gz" \
      "https://github.com/openai/codex/releases/download/rust-v$VERSIONE_CODEX/$nome.tar.gz"; then
    rm -rf "$temporanea"
    return 1
  fi
  if ! echo "$impronta  $temporanea/codex.tar.gz" | sha256sum -c - >/dev/null; then
    echo "L'archivio di Codex non ha l'impronta attesa: mi fermo."
    rm -rf "$temporanea"
    return 1
  fi
  rm -rf "$destinazione"
  install -d -m 755 -o root -g root "$destinazione" || { rm -rf "$temporanea"; return 1; }
  tar -xzf "$temporanea/codex.tar.gz" -C "$destinazione" --no-same-owner || { rm -rf "$temporanea"; return 1; }
  rm -rf "$temporanea"
  chown -R root:root "$destinazione"
  chmod -R go-w "$destinazione"
  [ -x "$destinazione/bin/codex" ] && [ -f "$destinazione/codex-package.json" ] || return 1
  # Il collegamento prende il posto del solo programma delle versioni prima.
  rm -f /usr/local/bin/codex
  ln -s "$destinazione/bin/codex" /usr/local/bin/codex || return 1
  [ "$(codex --version 2>/dev/null | awk '{print $2}')" = "$VERSIONE_CODEX" ]
}

file_agente() {
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/.claude"
  # Creata subito da agente: all'accesso sulla console la creerebbe root.
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/.cache"
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/boss"
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/progetti"
  # I segreti (password, token, chiavi) stanno qui, in un file per servizio.
  # Li scrive lo studente da SSH o dalla console, non nella conversazione.
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/segreti"
  chmod 700 "$CASA"

  # Impostazioni: si toccano solo le chiavi del kit. Remote Control non si
  # accende da solo: lo accende lo studente.
  local impostazioni="$CASA/.claude/settings.json"
  [ -s "$impostazioni" ] || echo '{}' > "$impostazioni"
  jq 'del(.remoteControlAtStartup) | .env.DISABLE_AUTOUPDATER = "1"' \
    "$impostazioni" > "$impostazioni.nuovo" && mv "$impostazioni.nuovo" "$impostazioni" || return 1

  # Onboarding già fatto e fiducia accettata solo per la cartella del boss,
  # senza cancellare quello che il login scrive nello stesso file. Per le
  # cartelle dei progetti la fiducia si dà una volta, quando si aprono.
  local configurazione="$CASA/.claude.json" versione
  versione="$(claude --version 2>/dev/null | awk '{print $1}')"
  [ -s "$configurazione" ] || echo '{}' > "$configurazione"
  jq --arg v "$versione" --arg cartella "$CASA/boss" '
      .hasCompletedOnboarding = true
    | .lastOnboardingVersion = (if $v == "" then .lastOnboardingVersion else $v end)
    | .theme = (.theme // "dark")
    | .projects[$cartella].hasTrustDialogAccepted = true' \
    "$configurazione" > "$configurazione.nuovo" && mv "$configurazione.nuovo" "$configurazione" || return 1
  chmod 600 "$configurazione"

  # Le istruzioni del boss. Se lo studente le ha già cambiate, restano le sue.
  # CLAUDE.md lo legge Claude, AGENTS.md lo legge Codex.
  local istruzioni
  for istruzioni in CLAUDE.md AGENTS.md; do
    if [ ! -e "$CASA/boss/$istruzioni" ]; then
      install -m 600 "$KIT_DIR/boss/$istruzioni" "$CASA/boss/$istruzioni" || return 1
    fi
  done

  # Ctrl+B è la combinazione di tmux. Ctrl+A è la seconda, se nella console
  # del pannello la prima non passa.
  if [ ! -e "$CASA/.tmux.conf" ]; then
    printf '%s\n' 'set -g prefix2 C-a' 'set -g focus-events on' \
      'set -g history-limit 10000' > "$CASA/.tmux.conf"
  fi

  if ! grep -q 'umask 077' "$CASA/.profile" 2>/dev/null; then
    # shellcheck disable=SC2016 # si espande al login di agente, non qui
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CASA/.profile"
    echo 'umask 077' >> "$CASA/.profile"
  fi
  chown -R "$UTENTE:$UTENTE" "$CASA/.claude" "$CASA/.claude.json" "$CASA/boss" \
    "$CASA/progetti" "$CASA/segreti" "$CASA/.profile" "$CASA/.tmux.conf"
}

# Syncthing tiene uguale una cartella fra la macchina e il computer dello
# studente, senza servizi in mezzo. Il kit lo lascia spento e pronto: crea
# l'identità della macchina, senza cartelle, e spegne le segnalazioni
# automatiche a chi sviluppa Syncthing. Accenderlo e collegare una cartella lo
# fa lo studente, chiedendolo al boss.
syncthing_pronto() {
  local configurazione="$CASA/.local/state/syncthing/config.xml"
  command -v syncthing >/dev/null || return 1
  if [ ! -s "$configurazione" ]; then
    runuser -l "$UTENTE" -c 'syncthing generate --no-default-folder' >/dev/null 2>&1 || return 1
  fi
  [ -s "$configurazione" ] || return 1
  sed -i 's|<urAccepted>[^<]*</urAccepted>|<urAccepted>-1</urAccepted>|;
          s|<crashReportingEnabled>[^<]*</crashReportingEnabled>|<crashReportingEnabled>false</crashReportingEnabled>|' \
    "$configurazione" || return 1
  grep -q '<urAccepted>-1</urAccepted>' "$configurazione" || return 1
  grep -q '<crashReportingEnabled>false</crashReportingEnabled>' "$configurazione" || return 1
  # L'interfaccia di Syncthing deve restare sulla sola macchina.
  grep -q '<address>127.0.0.1:8384</address>' "$configurazione" || return 1
  chown -R "$UTENTE:$UTENTE" "$CASA/.local"
}

comandi() {
  local comando
  for comando in "$KIT_DIR"/bin/*; do
    install -m 755 -o root -g root "$comando" /usr/local/bin/ || return 1
  done
  install -d -m 755 /usr/local/share/agenti-kit || return 1
  if [ -f "$KIT_DIR/VERSIONE" ]; then
    install -m 644 "$KIT_DIR/VERSIONE" /usr/local/share/agenti-kit/ || return 1
  fi
}

# Le sessioni le apre lo studente in tmux. Con il linger restano accese anche
# quando sulla console non c'è nessuno.
sessioni_che_restano() {
  [ "$SENZA_SYSTEMD" = 1 ] && return 0
  loginctl enable-linger "$UTENTE"
}

console_tty1() {
  install -m 644 -o "$UTENTE" -g "$UTENTE" "$KIT_DIR/console/bash_profile" "$CASA/.bash_profile"
  [ "$SENZA_SYSTEMD" = 1 ] && return 0
  install -d /etc/systemd/system/getty@tty1.service.d
  cat > /etc/systemd/system/getty@tty1.service.d/agenti-kit.conf <<FINE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $UTENTE --noclear %I \$TERM
FINE
  systemctl daemon-reload && systemctl restart getty@tty1.service
}

passo "sistema" sistema_base
passo "utente" utente_agente
passo "password" password_agente
passo "console-italiana" console_italiana
passo "ssh" ssh_con_password
passo "claude" claude_code
passo "codex" codex_cli
passo "file" file_agente
passo "syncthing" syncthing_pronto
passo "comandi" comandi
passo "installa" installa_senza_password
passo "sessioni" sessioni_che_restano
passo "console" console_tty1

if grep -q 'da-completare' "$STATO"; then
  echo "=== Installazione finita con passi da completare:"
  grep 'da-completare' "$STATO"
  exit 1
fi
echo "=== Installazione completa."
