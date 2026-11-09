#!/usr/bin/env bash
# Funzioni del profilo 24ORE, caricate da install.sh. Credenziali mai nel log.

plancia_24ore() {
  local versione=v1.2 impronta=7a2dbd9acc72a8ac2c7aaa0bdd9fa2364edadb0e49fef3779124680ec6a1af97
  local destinazione=/opt/session-board temporanea ip nome configurazione
  configurazione="$CASA/.config/session-board"
  temporanea="$(mktemp -d)" || return 1
  if ! riprova curl -fsSL --max-time 180 -o "$temporanea/board.tar.gz" \
      "https://github.com/tommasinigiovanni/alleniamoimprese-session-board/releases/download/$versione/session-board-portable.tar.gz"; then
    rm -rf "$temporanea"; return 1
  fi
  if ! echo "$impronta  $temporanea/board.tar.gz" | sha256sum -c - >/dev/null; then
    echo "La dashboard non ha l'impronta attesa: mi fermo."
    rm -rf "$temporanea"; return 1
  fi
  install -d -m 755 "$destinazione" || return 1
  tar -xzf "$temporanea/board.tar.gz" --strip-components=1 --no-same-owner -C "$destinazione" || return 1
  rm -rf "$temporanea"
  python3 -m venv "$destinazione/.venv" || return 1
  "$destinazione/.venv/bin/python" -m pip install --disable-pip-version-check -q \
    -r "$destinazione/requirements.txt" || return 1
  install -d -m 700 -o "$UTENTE" -g "$UTENTE" "$CASA/.config" "$configurazione" \
    "$CASA/.local" "$CASA/.local/state" "$CASA/.local/state/session-board" || return 1
  # Il segreto della sessione resta uguale anche dopo un rilancio del kit.
  if [ ! -e "$configurazione/service.env" ]; then
    ( umask 077
      python3 -c 'import secrets; print("BOARD_SECRET_KEY=" + secrets.token_hex(32))' \
        > "$configurazione/service.env"
    ) || return 1
    chown "$UTENTE:$UTENTE" "$configurazione/service.env" || return 1
  fi
  chmod 600 "$configurazione/service.env" || return 1
  install -m 644 "$KIT_DIR/profili/session-board-24ore.service" /etc/systemd/system/session-board.service || return 1
  DEBIAN_FRONTEND=noninteractive riprova "${APT[@]}" install -y -q caddy || return 1
  ip="${AGENTI_IPV4_PUBBLICO:-}"
  if [ -z "$ip" ]; then
    ip="$(curl --noproxy '*' -fsS --connect-timeout 3 --max-time 10 --retry 3 \
      http://169.254.169.254/hetzner/v1/metadata/public-ipv4)" || return 1
  fi
  python3 -c 'import ipaddress,sys; ipaddress.IPv4Address(sys.argv[1])' "$ip" || return 1
  nome="${ip//./-}.sslip.io"
  install -d -m 755 /etc/caddy/agenti-kit
  printf '%s\n' "$nome {" '    reverse_proxy 127.0.0.1:8099' '}' \
    > /etc/caddy/agenti-kit/plancia.caddy || return 1
  touch /etc/caddy/Caddyfile
  if ! grep -qxF 'import /etc/caddy/agenti-kit/*.caddy' /etc/caddy/Caddyfile; then
    printf '\n%s\n' 'import /etc/caddy/agenti-kit/*.caddy' >> /etc/caddy/Caddyfile
  fi
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile || return 1
  printf '%s\n' "https://$nome" > /usr/local/share/agenti-kit/plancia-url
  if [ "$SENZA_SYSTEMD" != 1 ]; then
    systemctl daemon-reload || return 1
    systemctl enable session-board.service || return 1
    systemctl enable --now caddy || return 1
    systemctl reload caddy || return 1
    # Una seconda installazione applica il codice senza cambiare password o MFA.
    if systemctl is-active --quiet session-board.service; then
      systemctl restart session-board.service || return 1
    fi
  fi
  echo "Dashboard installata: https://$nome. Primo accesso: plancia-attiva (da SSH come agente)."
}
