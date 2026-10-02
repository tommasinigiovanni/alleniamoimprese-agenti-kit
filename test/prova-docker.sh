#!/usr/bin/env bash
# Prova install.sh in un contenitore Ubuntu, senza systemd.
# Lo lancia due volte (deve reggere la seconda) e poi controlla lo stato.
# Esce con un errore se un controllo fallisce.
#
# Uso: test/prova-docker.sh [piattaforma] [immagine]
#      (es. linux/amd64 ubuntu:26.04; di base ubuntu:24.04)
set -euo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
PIATTAFORMA="${1:-}"
IMMAGINE="${2:-ubuntu:24.04}"
opzioni=(--rm -i -e AGENTI_SENZA_SYSTEMD=1)
[ -n "$PIATTAFORMA" ] && opzioni+=(--platform "$PIATTAFORMA")

# Il kit entra nel contenitore come archivio dallo standard input: niente
# cartelle condivise con il computer.
COPYFILE_DISABLE=1 tar -C "$RADICE" --no-xattrs --exclude ./dist --exclude ./.git -cf - . |
  docker run "${opzioni[@]}" "$IMMAGINE" bash -c '
    set -e
    mkdir -p /opt/agenti-kit && tar -xf - -C /opt/agenti-kit
    echo "v-prova" > /opt/agenti-kit/VERSIONE
    bash /opt/agenti-kit/install.sh > /tmp/prima.log 2>&1 || true
    tail -n 8 /tmp/prima.log
    echo "=== seconda esecuzione"
    bash /opt/agenti-kit/install.sh > /tmp/seconda.log 2>&1 || true
    tail -n 5 /tmp/seconda.log
    echo "=== verifica"
    esito=0
    bash /opt/agenti-kit/test/verifica-installazione.sh || esito=$?
    echo "=== salute come agente, senza login (deve dire cosa fare)"
    runuser -l agente -c "salute" || echo "(uscita diversa da 0, come previsto senza login)"
    echo "=== passi da completare nella prima esecuzione, con il contesto"
    grep -n -B2 -A8 "!!!" /tmp/prima.log | tail -n 60 || echo "nessuno"
    exit "$esito"
  '
