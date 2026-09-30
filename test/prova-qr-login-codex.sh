#!/usr/bin/env bash
# Prova qr-login-codex con un codex finto, che si comporta come
# "codex login --device-auth": stampa l'indirizzo e il codice, poi aspetta.
# Il login "riesce" quando compare un file, come se lo studente avesse
# scritto il codice nella pagina.
# Servono tmux e qrencode.
set -uo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
indirizzo="https://auth.esempio.com/codex/device"
codice="5XPD-E65UM"

TMUX_TMPDIR="$(mktemp -d)"
export TMUX_TMPDIR
trap 'tmux -L agenti-login-codex kill-server 2>/dev/null || true; rm -rf "$TMUX_TMPDIR"' EXIT

mkdir -p "$TMUX_TMPDIR/bin"
cat > "$TMUX_TMPDIR/bin/codex" <<FINE
#!/usr/bin/env bash
fatto="$TMUX_TMPDIR/login-fatto"
via="$TMUX_TMPDIR/codice-scritto"
rifiuta="$TMUX_TMPDIR/rifiuta"
if [ "\$1 \$2" = "login status" ]; then
  if [ -e "\$fatto" ]; then echo "Logged in using ChatGPT"; exit 0; fi
  echo "Not logged in"; exit 1
fi
if [ "\$1 \$2" = "login --device-auth" ]; then
  echo "Welcome to Codex [v0.0.0]"
  echo "Follow these steps to sign in with ChatGPT using device code authorization:"
  echo "1. Open this link in your browser and sign in to your account"
  echo "   $indirizzo"
  echo "2. Enter this one-time code (expires in 15 minutes)"
  echo "   $codice"
  if [ -e "\$rifiuta" ]; then
    sleep 2
    echo "Error: device code was denied"
    exit 1
  fi
  while [ ! -e "\$via" ]; do sleep 1; done
  touch "\$fatto"
  echo "Successfully logged in"
  exit 0
fi
FINE
chmod 755 "$TMUX_TMPDIR/bin/codex"
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
sessione_chiusa() { ! tmux -L agenti-login-codex has-session 2>/dev/null; }

# 1. Il login viene rifiutato: deve dirlo e uscire con errore.
touch "$TMUX_TMPDIR/rifiuta"
riuscito=0
uscita="$(bash "$RADICE/bin/qr-login-codex")" || riuscito=$?
controlla "mostra l'indirizzo per intero" riga_esatta "$uscita" "$indirizzo"
controlla "mostra il codice da scrivere nella pagina" contiene "$uscita" "      $codice"
controlla "c'è il QR" contiene "$uscita" '▀\|▄\|█'
controlla "login rifiutato: esce con errore" test "$riuscito" -ne 0
controlla "login rifiutato: lo dice" contiene "$uscita" "non è riuscito"
rm -f "$TMUX_TMPDIR/rifiuta"

# 2. Lo studente scrive il codice nella pagina dopo cinque secondi.
(sleep 8; touch "$TMUX_TMPDIR/codice-scritto") &
riuscito=0
uscita="$(bash "$RADICE/bin/qr-login-codex")" || riuscito=$?
wait
controlla "login riuscito: esce con 0" test "$riuscito" -eq 0
controlla "login riuscito: lo dice" contiene "$uscita" "Login di Codex fatto"
controlla "la sessione del login si chiude alla fine" sessione_chiusa

# 3. A login fatto non chiede niente.
uscita="$(bash "$RADICE/bin/qr-login-codex")" || true
controlla "a login fatto, non chiede niente" contiene "$uscita" "già fatto"

exit "$errori"
