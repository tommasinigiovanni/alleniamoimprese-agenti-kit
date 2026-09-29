#!/usr/bin/env bash
# Prova qr-login con un claude finto, che si comporta come "claude auth login":
# stampa l'indirizzo su una riga lunga, aspetta il codice, e lo accetta solo
# se è quello giusto. qr-login deve mostrare il QR dell'indirizzo intero,
# passare il codice, e dire se il login è riuscito.
# Servono tmux, qrencode e jq.
set -uo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
indirizzo="https://esempio.claude.com/cai/oauth/authorize?code=true&client_id=00000000-1111-2222-3333-444444444444&response_type=code&redirect_uri=https%3A%2F%2Fplatform.esempio.com%2Foauth%2Fcode%2Fcallback&scope=org%3Acreate_api_key+user%3Aprofile+user%3Ainference+user%3Asessions%3Aclaude_code+user%3Amcp_servers+user%3Afile_upload+user%3Aplugins&code_challenge=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq&code_challenge_method=S256&state=abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG"
codice_giusto="abc123#stato456"

TMUX_TMPDIR="$(mktemp -d)"
export TMUX_TMPDIR
trap 'tmux -L agenti-login kill-server 2>/dev/null || true; rm -rf "$TMUX_TMPDIR"' EXIT

mkdir -p "$TMUX_TMPDIR/bin"
cat > "$TMUX_TMPDIR/bin/claude" <<FINE
#!/usr/bin/env bash
fatto="$TMUX_TMPDIR/login-fatto"
if [ "\$1 \$2" = "auth status" ]; then
  if [ -e "\$fatto" ]; then echo '{"loggedIn": true}'; else echo '{"loggedIn": false}'; exit 1; fi
  exit 0
fi
if [ "\$1 \$2" = "auth login" ]; then
  echo "Opening browser to sign in…"
  echo "If the browser didn't open, visit: $indirizzo"
  printf 'Paste code here if prompted > '
  read -r codice
  if [ "\$codice" = "$codice_giusto" ]; then
    touch "\$fatto"
    echo "Login successful."
    exit 0
  fi
  echo "Login failed: Request failed with status code 400"
  exit 1
fi
FINE
chmod 755 "$TMUX_TMPDIR/bin/claude"
PATH="$TMUX_TMPDIR/bin:$PATH"
export PATH

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
# shellcheck disable=SC2317 # chiamate da controlla
contiene() { grep -q -- "$2" <<< "$1"; }
# shellcheck disable=SC2317
riga_esatta() { grep -qxF -- "$2" <<< "$1"; }
# shellcheck disable=SC2317
indirizzo_dopo_qr() {
  local riga_qr riga_indirizzo
  riga_qr="$(grep -n '█' <<< "$1" | tail -n 1 | cut -d: -f1)"
  riga_indirizzo="$(grep -n '^https://' <<< "$1" | head -n 1 | cut -d: -f1)"
  [ -n "$riga_qr" ] && [ -n "$riga_indirizzo" ] && [ "$riga_indirizzo" -gt "$riga_qr" ]
}
# shellcheck disable=SC2317
sessione_chiusa() { ! tmux -L agenti-login has-session 2>/dev/null; }

riuscito=0
uscita="$(printf '%s\n' "codice-sbagliato" | bash "$RADICE/bin/qr-login")" || riuscito=$?
controlla "qr-login ricompone l'indirizzo intero" riga_esatta "$uscita" "$indirizzo"
controlla "l'indirizzo sta sotto il QR" indirizzo_dopo_qr "$uscita"
controlla "c'è il QR" contiene "$uscita" '▀\|▄\|█'
controlla "con il codice sbagliato esce con errore" test "$riuscito" -ne 0
controlla "con il codice sbagliato lo dice" contiene "$uscita" "non è riuscito"

riuscito=0
uscita="$(printf '%s\n' "$codice_giusto" | bash "$RADICE/bin/qr-login")" || riuscito=$?
controlla "con il codice giusto esce con 0" test "$riuscito" -eq 0
controlla "con il codice giusto lo dice" contiene "$uscita" "Login fatto"
controlla "la sessione del login si chiude alla fine" sessione_chiusa

uscita="$(bash "$RADICE/bin/qr-login" < /dev/null)" || true
controlla "a login fatto, non chiede niente" contiene "$uscita" "già fatto"

exit "$errori"
