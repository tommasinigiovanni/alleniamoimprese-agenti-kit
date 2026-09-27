#!/usr/bin/env bash
# Prova qr-login su uno schermo come quello di /login in Claude Code: una riga
# rientrata, l'indirizzo spezzato con ritorni a capo veri ogni 80 caratteri,
# poi la riga rientrata "Paste code here". qr-login deve ricomporlo intero.
# Servono tmux e qrencode. La sessione di prova usa un socket tmux suo.
set -euo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
indirizzo="https://esempio.claude.com/cai/oauth/authorize?code=true&client_id=00000000-1111-2222-3333-444444444444&response_type=code&redirect_uri=https%3A%2F%2Fplatform.esempio.com%2Foauth%2Fcode%2Fcallback&scope=org%3Acreate_api_key+user%3Aprofile+user%3Ainference&code_challenge=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq&code_challenge_method=S256&state=abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG"

TMUX_TMPDIR="$(mktemp -d)"
export TMUX_TMPDIR
schermo="$TMUX_TMPDIR/schermo.txt"
trap 'tmux -L agenti kill-server 2>/dev/null || true; rm -rf "$TMUX_TMPDIR"' EXIT

{
  echo "  Login"
  echo "  Browser didn't open? Use the url below to sign in (c to copy)"
  printf '%s\n' "$indirizzo" | fold -w 80
  echo "  Paste code here if prompted >"
  echo "  Esc to cancel"
} > "$schermo"

# Un claude finto: il login risulta non fatto, così qr-login cerca l'indirizzo.
mkdir -p "$TMUX_TMPDIR/bin"
printf '%s\n' '#!/bin/sh' 'echo "{\"loggedIn\": false}"' > "$TMUX_TMPDIR/bin/claude"
chmod 755 "$TMUX_TMPDIR/bin/claude"
PATH="$TMUX_TMPDIR/bin:$PATH"
tmux -L agenti new-session -d -s claude -x 100 -y 40 "cat '$schermo'; sleep 60"
sleep 1

uscita="$(bash "$RADICE/bin/qr-login")"
if printf '%s\n' "$uscita" | grep -qxF "$indirizzo"; then
  echo "passa: qr-login ricompone l'indirizzo intero"
else
  echo "FALLISCE: indirizzo non ricomposto. Atteso:"
  echo "$indirizzo"
  echo "Trovato:"
  printf '%s\n' "$uscita" | tail -n 1
  exit 1
fi
if printf '%s\n' "$uscita" | grep -q '▀\|▄\|█'; then
  echo "passa: c'è il QR"
else
  echo "FALLISCE: niente QR"
  exit 1
fi
