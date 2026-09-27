#!/usr/bin/env bash
# shellcheck disable=SC2016 # i comandi fra apici si espandono nella bash -c, non qui
# Controlla lo stato della macchina dopo install.sh. Gira come root.
# Esce con 0 solo se tutti i controlli passano.
set -uo pipefail

errori=0
controlla() {
  local descrizione="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "passa: $descrizione"
  else
    echo "FALLISCE: $descrizione"
    errori=$((errori + 1))
  fi
}

CASA=/home/agente

controlla "l'utente agente esiste" id agente
controlla "agente non è nel gruppo sudo" bash -c '! id -nG agente | tr " " "\n" | grep -qxE "sudo|admin|wheel"'
controlla "agente non può usare sudo" bash -c '! runuser -u agente -- sudo -n true'
controlla "claude risponde" claude --version
controlla "la sorgente apt di Claude Code è firmata" grep -q 'signed-by=/etc/apt/keyrings/claude-code.asc' /etc/apt/sources.list.d/claude-code.list
controlla "settings.json accende Remote Control" bash -c "jq -e '.remoteControlAtStartup == true' $CASA/.claude/settings.json"
controlla "settings.json spegne l'aggiornamento automatico" bash -c "jq -e '.env.DISABLE_AUTOUPDATER == \"1\"' $CASA/.claude/settings.json"
controlla ".claude.json salta l'onboarding" bash -c "jq -e '.hasCompletedOnboarding == true' $CASA/.claude.json"
controlla ".claude.json si fida di ~/lavoro" bash -c "jq -e '.projects[\"$CASA/lavoro\"].hasTrustDialogAccepted == true' $CASA/.claude.json"
controlla ".claude.json leggibile solo da agente" bash -c "[ \"\$(stat -c %a $CASA/.claude.json)\" = 600 ]"
controlla "i file di agente sono di agente" bash -c "[ -z \"\$(find $CASA -not -user agente -print -quit)\" ]"
controlla "la cartella di lavoro ha il CLAUDE.md segnaposto" test -s "$CASA/lavoro/CLAUDE.md"
controlla "bun installato per agente" test -x "$CASA/.bun/bin/bun"
controlla "i comandi sono in /usr/local/bin" bash -c 'for c in agenti-menu salute-base qr-login riavvia-claude avvia-claude; do [ -x /usr/local/bin/$c ] || exit 1; done'
controlla "il servizio della sessione è abilitato" test -L "$CASA/.config/systemd/user/default.target.wants/claude-sessione.service"
controlla "il profilo apre il menu sulla console" grep -q agenti-menu "$CASA/.bash_profile"
controlla "il file di stato esiste" test -s /var/lib/agenti-kit/stato
controlla "il registro esiste" test -s /var/log/agenti-kit-install.log
controlla "fuso orario Europe/Rome" bash -c '[ "$(readlink -f /etc/localtime)" = /usr/share/zoneinfo/Europe/Rome ]'

estranei="$(find "$CASA" -not -user agente -printf '%u %p\n' 2>/dev/null | head -n 10)"
if [ -n "$estranei" ]; then
  echo "File nella casa di agente con un altro proprietario:"
  echo "$estranei"
fi

echo
echo "Stato dei passi:"
cat /var/lib/agenti-kit/stato
echo
if [ "$errori" -eq 0 ]; then
  echo "Tutti i controlli passano."
else
  echo "Controlli falliti: $errori."
fi
exit "$errori"
