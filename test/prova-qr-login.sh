#!/usr/bin/env bash
# Prova qr-login: una sessione tmux "claude" finta stampa un indirizzo lungo,
# che la finestra stretta manda a capo. qr-login deve ritrovarlo intero.
# Servono tmux e qrencode. La sessione di prova usa un socket tmux suo.
set -euo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
indirizzo="https://esempio.claude.ai/oauth/authorize?code=true&client_id=00000000-1111-2222-3333-444444444444&response_type=code&redirect_uri=https://esempio.anthropic.com/oauth/code/callback&scope=org-create_api_key_user-profile_user-inference&code_challenge=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq&code_challenge_method=S256&state=abcdefghijklmnopqrstuvwxyz0123456789"

TMUX_TMPDIR="$(mktemp -d)"
export TMUX_TMPDIR
trap 'tmux kill-server 2>/dev/null || true; rm -rf "$TMUX_TMPDIR"' EXIT

tmux new-session -d -s claude -x 80 -y 40 \
  "printf 'Browser non aperto? Usa questo indirizzo:\n%s\n' '$indirizzo'; sleep 60"
sleep 1

uscita="$(bash "$RADICE/bin/qr-login")"
if printf '%s\n' "$uscita" | grep -qxF "$indirizzo"; then
  echo "passa: qr-login ritrova l'indirizzo intero"
else
  echo "FALLISCE: indirizzo non ritrovato"
  printf '%s\n' "$uscita" | tail -n 3
  exit 1
fi
if printf '%s\n' "$uscita" | grep -q '▀\|▄\|█'; then
  echo "passa: c'è il QR"
else
  echo "FALLISCE: niente QR"
  exit 1
fi
