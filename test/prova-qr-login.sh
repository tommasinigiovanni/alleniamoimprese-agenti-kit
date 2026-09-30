#!/usr/bin/env bash
# Prova qr-login-claude con un claude finto, che si comporta come "claude auth login":
# stampa l'indirizzo su una riga lunga, aspetta il codice, e lo accetta solo
# se è quello giusto. qr-login-claude deve mostrare il QR dell'indirizzo intero,
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
  if [ "\$codice" = "\$(cat "$TMUX_TMPDIR/codice-giusto")" ]; then
    touch "\$fatto"
    echo "Login successful."
    exit 0
  fi
  echo "Login failed: Request failed with status code 400"
  exit 1
fi
FINE
chmod 755 "$TMUX_TMPDIR/bin/claude"
printf '%s' "$codice_giusto" > "$TMUX_TMPDIR/codice-giusto"
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
uscita="$(printf '%s\n' "codice-sbagliato" | bash "$RADICE/bin/qr-login-claude")" || riuscito=$?
controlla "qr-login-claude ricompone l'indirizzo intero" riga_esatta "$uscita" "$indirizzo"
controlla "l'indirizzo sta sotto il QR" indirizzo_dopo_qr "$uscita"
controlla "c'è il QR" contiene "$uscita" '▀\|▄\|█'
controlla "con il codice sbagliato esce con errore" test "$riuscito" -ne 0
controlla "con il codice sbagliato lo dice" contiene "$uscita" "non è riuscito"

riuscito=0
uscita="$(printf '%s\n' "$codice_giusto" | bash "$RADICE/bin/qr-login-claude")" || riuscito=$?
controlla "con il codice giusto esce con 0" test "$riuscito" -eq 0
controlla "con il codice giusto lo dice" contiene "$uscita" "Login fatto"
controlla "la sessione del login si chiude alla fine" sessione_chiusa

uscita="$(bash "$RADICE/bin/qr-login-claude" < /dev/null)" || true
controlla "a login fatto, non chiede niente" contiene "$uscita" "già fatto"

# Il codice trasformato dalla pagina "Login senza telefono": sole lettere e
# numeri. È lo stesso codice di sopra, abc123#stato456.
trasformato="zzmfrggmjsgmrxg5dborxtinjw29ad"
rm -f "$TMUX_TMPDIR/login-fatto"
riuscito=0
uscita="$(printf '%s\n' "$trasformato" | bash "$RADICE/bin/qr-login-claude")" || riuscito=$?
controlla "codice trasformato: il login riesce" test "$riuscito" -eq 0
controlla "codice trasformato: lo dice" contiene "$uscita" "Login fatto"

# Lo stesso, con una lettera persa nell'incolla: deve accorgersene e chiedere
# di nuovo, senza mandare a Claude un codice sbagliato. Alla seconda riga
# arriva quello giusto.
rovinato="zzmfrggmjsgmrxg5dborxtinj29ad"
rm -f "$TMUX_TMPDIR/login-fatto"
riuscito=0
uscita="$(printf '%s\n%s\n' "$rovinato" "$trasformato" | bash "$RADICE/bin/qr-login-claude")" || riuscito=$?
controlla "codice rovinato: se ne accorge" contiene "$uscita" "arrivato rovinato"
controlla "codice rovinato: poi accetta quello giusto" test "$riuscito" -eq 0

# Un codice lungo, con trattini, trattini bassi e cancelletto, come quello vero.
lungo='K7f_2Xq-9LmN0pQrStUvWxYz_-AbCdEfGhIjKlMnOpQrStUv#aB3_dE-fG7hIjK1LmN0pQrStUvWxYz_-0123456789AbC'
lungo_trasformato="zzjm3wmxzslbys2okmnvhda4crojjxivlwk54fs6s7fvaweq3eivteo2cjnjfwytloj5yfc4storkxmi3biizv6zcffvteon3ijfvewmkmnvhda4crojjxivlwk54fs6s7fuydcmrtgq2tmnzyhfaweqy7993"
printf '%s' "$lungo" > "$TMUX_TMPDIR/codice-giusto"
rm -f "$TMUX_TMPDIR/login-fatto"
riuscito=0
uscita="$(printf '%s\n' "$lungo_trasformato" | bash "$RADICE/bin/qr-login-claude")" || riuscito=$?
controlla "codice lungo trasformato: il login riesce" test "$riuscito" -eq 0

# Lo stesso codice lungo, scritto a mano così com'è.
rm -f "$TMUX_TMPDIR/login-fatto"
riuscito=0
uscita="$(printf '%s\n' "$lungo" | bash "$RADICE/bin/qr-login-claude")" || riuscito=$?
controlla "codice lungo scritto a mano: il login riesce" test "$riuscito" -eq 0

exit "$errori"
