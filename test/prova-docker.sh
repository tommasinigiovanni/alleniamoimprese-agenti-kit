#!/usr/bin/env bash
# Prova install.sh in un contenitore ubuntu:24.04, senza systemd.
# Lo lancia due volte (deve reggere la seconda) e poi controlla lo stato.
#
# Uso: test/prova-docker.sh [piattaforma]   (es. linux/amd64)
set -euo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
PIATTAFORMA="${1:-}"
opzioni=(--rm -i -e AGENTI_SENZA_SYSTEMD=1)
[ -n "$PIATTAFORMA" ] && opzioni+=(--platform "$PIATTAFORMA")

# Il kit entra nel contenitore come archivio dallo standard input: niente
# cartelle condivise con il computer.
COPYFILE_DISABLE=1 tar -C "$RADICE" --exclude ./dist --exclude ./.git -cf - . |
  docker run "${opzioni[@]}" ubuntu:24.04 bash -c '
    set -e
    mkdir -p /opt/agenti-kit && tar -xf - -C /opt/agenti-kit
    echo "v-prova" > /opt/agenti-kit/VERSIONE
    bash /opt/agenti-kit/install.sh > /tmp/prima.log 2>&1 || true
    tail -n 8 /tmp/prima.log
    echo "=== seconda esecuzione"
    bash /opt/agenti-kit/install.sh > /tmp/seconda.log 2>&1 || true
    tail -n 5 /tmp/seconda.log
    echo "=== verifica"
    bash /opt/agenti-kit/test/verifica-installazione.sh || true
    echo "=== salute-base come agente, senza login (deve dire cosa fare)"
    runuser -l agente -c "salute-base" || echo "(uscita diversa da 0, come previsto senza login)"
    echo "=== passi da completare nella prima esecuzione, con il contesto"
    grep -n -B2 -A8 "!!!" /tmp/prima.log | tail -n 60 || echo "nessuno"
  '
