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
PLUGIN_TELEGRAM="telegram@claude-plugins-official"
MARKETPLACE="anthropics/claude-plugins-official"

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

# Esegue un comando come agente, con la sua casa e il suo PATH.
come_agente() {
  runuser -l "$UTENTE" -c "export PATH=\"\$HOME/.bun/bin:\$HOME/.local/bin:\$PATH\"; $1"
}

sistema_base() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q &&
    apt-get install -y -q tmux git qrencode jq unzip curl ca-certificates \
      gnupg tzdata unattended-upgrades iproute2 || return 1
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

# Nessuno entra da fuori: niente server SSH. Il firewall del pannello chiude
# comunque tutto; questo toglie anche il servizio.
niente_ssh() {
  [ "$SENZA_SYSTEMD" = 1 ] && return 0
  systemctl disable --now ssh.socket ssh.service >/dev/null 2>&1 || true
  ! systemctl is-active --quiet ssh.service
}

claude_code() {
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL --retry 3 https://downloads.claude.ai/keys/claude-code.asc \
    -o /etc/apt/keyrings/claude-code.asc || return 1
  echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
    > /etc/apt/sources.list.d/claude-code.list
  apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -y -q claude-code || return 1
  command -v claude >/dev/null
}

file_agente() {
  install -d -o "$UTENTE" -g "$UTENTE" -m 700 "$CASA/.claude"
  install -d -o "$UTENTE" -g "$UTENTE" -m 755 "$CASA/lavoro"

  # Impostazioni: si toccano solo le chiavi del kit.
  local impostazioni="$CASA/.claude/settings.json"
  [ -s "$impostazioni" ] || echo '{}' > "$impostazioni"
  jq '.remoteControlAtStartup = true | .env.DISABLE_AUTOUPDATER = "1"' \
    "$impostazioni" > "$impostazioni.nuovo" && mv "$impostazioni.nuovo" "$impostazioni" || return 1

  # Onboarding e fiducia della cartella già accettati, senza cancellare
  # quello che il login scrive nello stesso file.
  local configurazione="$CASA/.claude.json" versione
  versione="$(claude --version 2>/dev/null | awk '{print $1}')"
  [ -s "$configurazione" ] || echo '{}' > "$configurazione"
  jq --arg v "$versione" --arg cartella "$CASA/lavoro" '
      .hasCompletedOnboarding = true
    | .lastOnboardingVersion = (if $v == "" then .lastOnboardingVersion else $v end)
    | .theme = (.theme // "dark")
    | .projects[$cartella].hasTrustDialogAccepted = true' \
    "$configurazione" > "$configurazione.nuovo" && mv "$configurazione.nuovo" "$configurazione" || return 1
  chmod 600 "$configurazione"

  if [ ! -e "$CASA/lavoro/CLAUDE.md" ]; then
    cat > "$CASA/lavoro/CLAUDE.md" <<'FINE'
# La mia macchina

Macchina appena creata. Il repository con il mio sistema arriva nella seconda
live: fino ad allora qui c'è solo questo file.

- Quello che deve durare sta nei file, non nella conversazione.
- Non chiedere e non scrivere mai password, chiavi o token nella
  conversazione: si inseriscono dal menu della console.
FINE
  fi

  if [ ! -e "$CASA/.tmux.conf" ]; then
    printf '%s\n' 'set -g focus-events on' 'set -g history-limit 10000' > "$CASA/.tmux.conf"
  fi

  if ! grep -q '.bun/bin' "$CASA/.profile" 2>/dev/null; then
    # shellcheck disable=SC2016 # si espande al login di agente, non qui
    echo 'export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"' >> "$CASA/.profile"
  fi
  chown -R "$UTENTE:$UTENTE" "$CASA/.claude" "$CASA/.claude.json" "$CASA/lavoro" \
    "$CASA/.profile" "$CASA/.tmux.conf"
}

bun_agente() {
  if [ ! -x "$CASA/.bun/bin/bun" ]; then
    come_agente 'curl -fsSL --retry 3 https://bun.sh/install | bash' || return 1
  fi
  [ -x "$CASA/.bun/bin/bun" ]
}

plugin_telegram() {
  come_agente "claude plugin marketplace add $MARKETPLACE >/dev/null 2>&1 || true
               claude plugin install $PLUGIN_TELEGRAM -s user -y" || return 1
  come_agente "claude plugin list 2>/dev/null" | grep -q telegram
}

comandi() {
  local comando
  for comando in "$KIT_DIR"/bin/*; do
    install -m 755 -o root -g root "$comando" /usr/local/bin/
  done
  install -d -m 755 /usr/local/share/agenti-kit
  cp "$KIT_DIR/VERSIONE" /usr/local/share/agenti-kit/ 2>/dev/null || true
}

sessione_claude() {
  local cartella="$CASA/.config/systemd/user"
  install -d -o "$UTENTE" -g "$UTENTE" "$CASA/.config" "$CASA/.config/systemd" \
    "$cartella" "$cartella/default.target.wants"
  install -m 644 -o "$UTENTE" -g "$UTENTE" "$KIT_DIR/systemd/claude-sessione.service" "$cartella/"
  ln -sfn ../claude-sessione.service "$cartella/default.target.wants/claude-sessione.service"
  chown -h "$UTENTE:$UTENTE" "$cartella/default.target.wants/claude-sessione.service"
  [ "$SENZA_SYSTEMD" = 1 ] && return 0
  loginctl enable-linger "$UTENTE" || return 1
  # Il gestore dei servizi di agente parte con il linger: si aspetta un attimo.
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    systemctl --user --machine="$UTENTE@" daemon-reload >/dev/null 2>&1 && break
    sleep 2
  done
  systemctl --user --machine="$UTENTE@" restart claude-sessione.service
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
passo "ssh" niente_ssh
passo "claude" claude_code
passo "file" file_agente
passo "bun" bun_agente
passo "plugin" plugin_telegram
passo "comandi" comandi
passo "sessione" sessione_claude
passo "console" console_tty1

if grep -q 'da-completare' "$STATO"; then
  echo "=== Installazione finita con passi da completare:"
  grep 'da-completare' "$STATO"
else
  echo "=== Installazione completa."
fi
