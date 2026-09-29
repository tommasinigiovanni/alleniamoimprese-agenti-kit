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
# Nei primi minuti di una macchina nuova gli aggiornamenti automatici di Ubuntu
# tengono occupato apt: si aspetta che lo liberino, fino a dieci minuti.
APT=(apt-get -o DPkg::Lock::Timeout=600)

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
  riprova "${APT[@]}" install -y -q tmux git qrencode jq unzip curl ca-certificates \
    gnupg tzdata unattended-upgrades iproute2 openssh-server || return 1
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
  passwd -l "$UTENTE" >/dev/null
  # L'agente non è mai amministratore.
  local gruppo
  for gruppo in sudo admin wheel; do
    gpasswd -d "$UTENTE" "$gruppo" >/dev/null 2>&1 || true
  done
  ! id -nG "$UTENTE" | tr ' ' '\n' | grep -qxE 'sudo|admin|wheel'
}

# SSH acceso ma chiuso: si entra solo con una chiave, solo come agente, e
# agente all'inizio non ne ha nessuna. Da fuori la porta non si vede finché lo
# studente non la apre nel firewall del pannello.
# Il nome comincia con 00: in sshd vale il primo valore letto, e cloud-init
# scrive il suo file (50-cloud-init.conf) con le password accese.
ssh_solo_chiave() {
  install -d -m 755 /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/00-agenti-kit.conf <<'FINE'
# Kit del corso "Agenti che non dormono".
PasswordAuthentication no
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
  printf '%s\n' "$valori" | grep -qx 'passwordauthentication no' || return 1
  printf '%s\n' "$valori" | grep -qx 'permitrootlogin no' || return 1
  [ "$SENZA_SYSTEMD" = 1 ] && return 0
  local unita
  for unita in ssh.socket ssh.service; do
    systemctl unmask "$unita" >/dev/null 2>&1 || true
  done
  systemctl daemon-reload
  # Su Ubuntu 24.04 il server parte dal socket, alla prima connessione.
  if systemctl list-unit-files ssh.socket >/dev/null 2>&1; then
    systemctl enable --now ssh.socket >/dev/null 2>&1 || return 1
  else
    systemctl enable --now ssh.service >/dev/null 2>&1 || return 1
  fi
  systemctl try-restart ssh.service >/dev/null 2>&1 || true
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
  DEBIAN_FRONTEND=noninteractive riprova "${APT[@]}" install -y -q claude-code || return 1
  command -v claude >/dev/null
}

file_agente() {
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/.claude"
  # Creata subito da agente: all'accesso sulla console la creerebbe root.
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/.cache"
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/boss"
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/progetti"
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
  if [ ! -e "$CASA/boss/CLAUDE.md" ]; then
    install -m 600 "$KIT_DIR/boss/CLAUDE.md" "$CASA/boss/CLAUDE.md" || return 1
  fi

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
    "$CASA/progetti" "$CASA/.profile" "$CASA/.tmux.conf"
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
passo "ssh" ssh_solo_chiave
passo "claude" claude_code
passo "file" file_agente
passo "comandi" comandi
passo "sessioni" sessioni_che_restano
passo "console" console_tty1

if grep -q 'da-completare' "$STATO"; then
  echo "=== Installazione finita con passi da completare:"
  grep 'da-completare' "$STATO"
  exit 1
fi
echo "=== Installazione completa."
