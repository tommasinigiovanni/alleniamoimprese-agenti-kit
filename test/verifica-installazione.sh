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
controlla "codex risponde, alla versione fissata" bash -c '[ "$(codex --version | cut -d" " -f2)" = "$(sed -n "s/^VERSIONE_CODEX=\"\(.*\)\"/\1/p" /opt/agenti-kit/install.sh)" ]'
controlla "codex è di root e non si può cambiare" bash -c '[ "$(stat -L -c %U:%a /usr/local/bin/codex)" = root:755 ] && [ -z "$(find -L /opt/codex-* -perm /022 -print -quit)" ]'
controlla "codex è il pacchetto completo" bash -c 'test -f "$(dirname "$(dirname "$(readlink -f /usr/local/bin/codex)")")/codex-package.json"'
# Il solo programma rispondeva a --version ma si fermava alla prima sessione:
# qui lo si lancia davvero, come fa lo studente.
controlla "codex apre una sessione, non si ferma con un errore" bash -c 'runuser -l agente -c "mkdir -p /tmp/prova-codex; tmux -L prova-codex kill-server 2>/dev/null; tmux -L prova-codex new-session -d -s c -x 120 -y 30 -c /tmp/prova-codex codex; sleep 10; tmux -L prova-codex capture-pane -p -t c > /tmp/prova-codex/schermo.txt; tmux -L prova-codex kill-server; pkill -u agente -f app-server; true"; grep -q "Welcome to Codex" /tmp/prova-codex/schermo.txt && ! grep -q "no complete local package" /tmp/prova-codex/schermo.txt'
controlla "agente può lanciare codex" runuser -l agente -c "codex --version"
controlla "la sorgente apt di Claude Code è firmata" grep -q 'signed-by=/etc/apt/keyrings/claude-code.asc' /etc/apt/sources.list.d/claude-code.list
controlla "Remote Control non si accende da solo: lo accende lo studente" bash -c "jq -e '.remoteControlAtStartup != true' $CASA/.claude/settings.json"
controlla "settings.json spegne l'aggiornamento automatico" bash -c "jq -e '.env.DISABLE_AUTOUPDATER == \"1\"' $CASA/.claude/settings.json"
controlla ".claude.json salta l'onboarding" bash -c "jq -e '.hasCompletedOnboarding == true' $CASA/.claude.json"
controlla ".claude.json si fida di ~/boss" bash -c "jq -e '.projects[\"$CASA/boss\"].hasTrustDialogAccepted == true' $CASA/.claude.json"
controlla ".claude.json leggibile solo da agente" bash -c "[ \"\$(stat -c %a $CASA/.claude.json)\" = 600 ]"
controlla "la casa di agente è chiusa agli altri" bash -c "[ \"\$(stat -c %a $CASA)\" = 700 ]"
controlla "la cartella del boss è chiusa agli altri" bash -c "[ \"\$(stat -c %a $CASA/boss)\" = 700 ]"
controlla "la cartella dei progetti esiste" test -d "$CASA/progetti"
controlla "la chiave apt è quella di Anthropic" bash -c "GNUPGHOME=\$(mktemp -d) gpg --show-keys --with-colons /etc/apt/keyrings/claude-code.asc | grep -q 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
controlla "tastiera italiana" grep -qx 'XKBLAYOUT="it"' /etc/default/keyboard
controlla "carattere della console con i mezzi blocchi" bash -c 'grep -qx "FONTFACE=\"VGA\"" /etc/default/console-setup && grep -qx "FONTSIZE=\"8x14\"" /etc/default/console-setup'
controlla "il carattere VGA 8x14 ha i mezzi blocchi del QR" bash -c 'zcat /usr/share/consolefonts/Uni2-VGA14.psf.gz > /tmp/carattere.psf && psfgettable /tmp/carattere.psf | grep -qi "U+2580" && psfgettable /tmp/carattere.psf | grep -qi "U+2584"'
controlla "tastiera e carattere salvati per i prossimi avvii" bash -c 'ls /etc/console-setup/cached_*.kmap.gz && ls /etc/console-setup/cached_Uni2-VGA14.psf.gz'
controlla "il promemoria non usa la tilde" bash -c '! grep -q "~" /usr/local/bin/aiuto'
controlla "syncthing installato" command -v syncthing
controlla "syncthing ha l'identità della macchina" test -s "$CASA/.local/state/syncthing/cert.pem"
controlla "syncthing parte senza cartelle" bash -c "! grep -q '<folder id=\"[^\"]' $CASA/.local/state/syncthing/config.xml"
controlla "syncthing non manda segnalazioni automatiche" bash -c "grep -q '<urAccepted>-1</urAccepted>' $CASA/.local/state/syncthing/config.xml && grep -q '<crashReportingEnabled>false</crashReportingEnabled>' $CASA/.local/state/syncthing/config.xml"
controlla "l'interfaccia di syncthing resta sulla macchina" grep -q '<address>127.0.0.1:8384</address>' "$CASA/.local/state/syncthing/config.xml"
controlla "syncthing è spento: lo accende lo studente" bash -c "! pgrep -x syncthing && [ ! -e $CASA/.config/systemd/user/default.target.wants/syncthing.service ]"
controlla "il boss sa collegare una cartella" grep -q "syncthing cli config folders" "$CASA/boss/CLAUDE.md"
controlla "il server SSH è installato" test -x /usr/sbin/sshd
controlla "SSH: niente password" bash -c 'mkdir -p /run/sshd; sshd -T 2>/dev/null | grep -qx "passwordauthentication no"'
controlla "SSH: niente domande a tastiera" bash -c 'sshd -T 2>/dev/null | grep -qx "kbdinteractiveauthentication no"'
controlla "SSH: root non entra" bash -c 'sshd -T 2>/dev/null | grep -qx "permitrootlogin no"'
controlla "SSH: entra solo agente" bash -c 'sshd -T 2>/dev/null | grep -qx "allowusers agente"'
controlla "SSH: agente non ha ancora nessuna chiave" bash -c "[ ! -s $CASA/.ssh/authorized_keys ]"
if [ -d /run/systemd/system ]; then
  controlla "SSH non è mascherato" bash -c '[ "$(systemctl is-enabled ssh.service 2>/dev/null)" != masked ] && [ "$(systemctl is-enabled ssh.socket 2>/dev/null)" != masked ]'
fi
# All'accesso automatico sulla console un file può essere di root per un
# istante: si ricontrolla dopo tre secondi prima di dare errore.
controlla "i file di agente sono di agente" bash -c "[ -z \"\$(find $CASA -not -user agente -print -quit)\" ] || { sleep 3; [ -z \"\$(find $CASA -not -user agente -print -quit)\" ]; }"
controlla "il boss ha le sue istruzioni" grep -q "tmux new-session" "$CASA/boss/CLAUDE.md"
controlla "il boss ha le istruzioni anche per Codex" grep -q "tmux new-session" "$CASA/boss/AGENTS.md"
controlla "niente Bun e niente plugin Telegram" bash -c "[ ! -e $CASA/.bun ] && [ ! -e $CASA/.claude/plugins ]"
controlla "i comandi sono in /usr/local/bin" bash -c 'for c in salute qr-login-claude qr-login-codex aiuto; do [ -x /usr/local/bin/$c ] || exit 1; done'
controlla "i comandi della v0.1 non ci sono" bash -c 'for c in agenti-menu salute-base riavvia-claude avvia-claude qr-login; do [ ! -e /usr/local/bin/$c ] || exit 1; done'
controlla "nessuna sessione di Claude che parte da sola" bash -c "[ ! -e $CASA/.config/systemd/user/claude-sessione.service ]"
controlla "la console apre la shell con il benvenuto, non il menu" bash -c "grep -q aiuto $CASA/.bash_profile && ! grep -q agenti-menu $CASA/.bash_profile"
controlla "tmux ha la seconda combinazione, Ctrl+A" grep -q "prefix2 C-a" "$CASA/.tmux.conf"
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
