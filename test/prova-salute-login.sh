#!/usr/bin/env bash
# Prova le righe del login in salute, con un claude e un codex finti: ne basta
# uno dei due, e l'altro non conta fra le cose da fare.
# Serve jq.
set -uo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
FINTI="$(mktemp -d)"
trap 'rm -rf "$FINTI"' EXIT

cat > "$FINTI/claude" <<'DENTRO'
#!/usr/bin/env bash
if [ "$1 $2" = "auth status" ]; then
  if [ "${CLAUDE_DENTRO:-no}" = si ]; then
    echo '{"loggedIn": true, "subscriptionType": "pro"}'
  else
    echo '{"loggedIn": false}'
  fi
  exit 0
fi
echo "0.0.0 (Claude Code)"
DENTRO
cat > "$FINTI/codex" <<'DENTRO'
#!/usr/bin/env bash
if [ "$1 $2" = "login status" ]; then
  [ "${CODEX_DENTRO:-no}" = si ] && exit 0
  exit 1
fi
echo "codex-cli 0.0.0"
DENTRO
chmod 755 "$FINTI/claude" "$FINTI/codex"

errori=0
# caso DESCRIZIONE CLAUDE CODEX RIGA-ATTESA...
caso() {
  local descrizione="$1" claude="$2" codex="$3" uscita attesa
  shift 3
  uscita="$(PATH="$FINTI:$PATH" CLAUDE_DENTRO="$claude" CODEX_DENTRO="$codex" bash "$RADICE/bin/salute" 2>/dev/null)"
  for attesa in "$@"; do
    if grep -qF -- "$attesa" <<< "$uscita"; then
      echo "passa: $descrizione: $attesa"
    else
      echo "FALLISCE: $descrizione: manca \"$attesa\""
      errori=$((errori + 1))
    fi
  done
}

caso "nessun login" no no \
  "[DA FARE] Fai il login: qr-login-claude. Se usi solo Codex: qr-login-codex" \
  "[--]      Login di Codex non fatto"
caso "solo Claude" si no \
  "[OK]      Login di Claude fatto (abbonamento: pro)" \
  "[--]      Login di Codex non fatto"
caso "solo Codex" no si \
  "[--]      Login di Claude non fatto. Se lo usi: qr-login-claude" \
  "[OK]      Login di Codex fatto"
caso "tutti e due" si si \
  "[OK]      Login di Claude fatto" \
  "[OK]      Login di Codex fatto"

exit "$errori"
