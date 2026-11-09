#!/usr/bin/env bash
# Su una VM CI usa e verifica chiavi generate solo per questa prova.
set -euo pipefail
RADICE="$(cd "$(dirname "$0")/.." && pwd)"
test "$(id -u)" = 0
test -n "${AGENTI_TEST_KEY:-}"

ssh_prova() {
  ssh -i "$AGENTI_TEST_KEY" -p 2222 -o IdentitiesOnly=yes -o BatchMode=yes \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$@"
}
sshd -T | grep -qx 'port 2222'
sshd -T | grep -qx 'passwordauthentication no'
sshd -T | grep -qx 'kbdinteractiveauthentication no'
sshd -T | grep -qx 'pubkeyauthentication yes'
sshd -T | grep -qxE 'permitrootlogin (without-password|prohibit-password)'
test "$(sshd -T | awk '$1 == "allowusers" {for (i=2; i<=NF; i++) print $i}' | sort | paste -sd' ' -)" = 'agente root'
ssh_prova agente@127.0.0.1 whoami | grep -x agente
ssh_prova root@127.0.0.1 whoami | grep -x root
ssh_prova agente@127.0.0.1 'sudo -n whoami' | grep -x root
if ssh_prova -o PreferredAuthentications=password agente@127.0.0.1 true; then exit 1; fi
if ssh_prova -o PreferredAuthentications=password root@127.0.0.1 true; then exit 1; fi
if ssh -p 22 -o BatchMode=yes -o ConnectTimeout=3 agente@127.0.0.1 true; then exit 1; fi
test ! -e /home/agente/.password-iniziale
test "$(stat -c %U:%a /home/agente/.ssh/authorized_keys)" = agente:600
test "$(stat -c %U:%a /home/agente/.ssh)" = agente:700
test "$(stat -c %U:%a /home/agente/.config/session-board/service.env)" = agente:600
jq -e '.permissions.ask | index("Bash(sudo:*)")' /home/agente/.claude/settings.json
systemctl is-enabled session-board.service
test "$(systemctl show -p User --value session-board.service)" = agente
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
test -x /opt/session-board/.venv/bin/python
test -s /usr/local/share/agenti-kit/plancia-url
# Disconnessione e rientro reali: il programma rimane nella sessione di agente.
ssh_prova agente@127.0.0.1 'tmux new-session -d -s prova-24ore; tmux send-keys -t prova-24ore "sleep 3; echo finito > /home/agente/prova-persistenza" Enter'
sleep 4
ssh_prova agente@127.0.0.1 'tmux has-session -t prova-24ore && grep -x finito /home/agente/prova-persistenza'
ssh_prova agente@127.0.0.1 'tmux kill-session -t prova-24ore'
# Secondo avvio del kit: profilo ricordato, chiavi e segreto non cambiano.
prima="$(sha256sum /home/agente/.ssh/authorized_keys /home/agente/.config/session-board/service.env)"
bash "$RADICE/install.sh"
test "$prima" = "$(sha256sum /home/agente/.ssh/authorized_keys /home/agente/.config/session-board/service.env)"
ssh_prova agente@127.0.0.1 whoami | grep -x agente
ssh_prova root@127.0.0.1 whoami | grep -x root
# Attivazione con dati fittizi: mai usare credenziali personali nella CI.
runuser -u agente -- env HOME=/home/agente /opt/session-board/.venv/bin/python - <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, '/opt/session-board')
from werkzeug.security import generate_password_hash
from session_board.mfa_store import MFAStore
dest = Path.home()/'.config/session-board/password.hash'
dest.write_text(generate_password_hash('password-fittizia-solo-ci', method='scrypt')+'\n')
dest.chmod(0o600)
MFAStore(Path.home()/'.local/state/session-board/auth').prepare_enrollment('admin')
PY
systemctl start session-board.service
for _ in {1..20}; do
  if curl -fsS -o /dev/null http://127.0.0.1:8099/login; then break; fi
  sleep 1
done
test "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8099/)" = 302
systemctl is-active --quiet session-board.service
test "$(ps -o user= -p "$(systemctl show -p MainPID --value session-board.service)" | xargs)" = agente
echo '24ORE: chiavi root/agente, sudo, tmux, seconda installazione e dashboard verificati.'
