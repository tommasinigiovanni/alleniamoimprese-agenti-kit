#!/usr/bin/env python3
"""Autorizza su agente le chiavi pubbliche inserite da Hetzner in root.

Non copia chiavi private e non rimuove le autorizzazioni già presenti.
Le righe con opzioni (per esempio un comando forzato da cloud-init) non sono
convertite in autorizzazioni libere: serve disable_root: false nel cloud-init.
"""
import argparse
import os
from pathlib import Path
import pwd
import subprocess
import tempfile


def selected_keys(source):
    keys = []
    for line in source.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split()
        if len(parts) < 2 or not parts[0].startswith(('ssh-', 'ecdsa-', 'sk-')):
            continue
        with tempfile.NamedTemporaryFile(mode='w') as test:
            test.write(line + '\n')
            test.flush()
            result = subprocess.run(['ssh-keygen', '-lf', test.name], capture_output=True)
        if result.returncode != 0:
            raise ValueError('Una chiave pubblica di root non è valida.')
        if parts[:2] not in [key.split()[:2] for key in keys]:
            keys.append(line)
    if not keys:
        raise ValueError('Nessuna chiave pubblica utilizzabile in root. Seleziona una chiave in Hetzner e usa il cloud-init 24ORE (disable_root: false).')
    return keys


def authorize(source, destination, owner):
    keys = selected_keys(source)  # Non toccare destinazione se manca la chiave.
    account = pwd.getpwnam(owner)
    if destination.is_symlink() or destination.parent.is_symlink():
        raise ValueError('La destinazione SSH non può essere un collegamento simbolico.')
    previous = destination.read_text() if destination.exists() else ''
    present = [line.split()[:2] for line in previous.splitlines()]
    added = [key for key in keys if key.split()[:2] not in present]
    content = previous.rstrip('\n')
    if added:
        content = '\n'.join(([content] if content else []) + added)
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(destination.parent, 0o700)
    os.chown(destination.parent, account.pw_uid, account.pw_gid)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=destination.parent, delete=False) as handle:
            temporary = Path(handle.name)
            os.fchmod(handle.fileno(), 0o600)
            os.fchown(handle.fileno(), account.pw_uid, account.pw_gid)
            handle.write(content + '\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, destination)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(f'Chiavi SSH autorizzate per {owner}: {len(keys)}; chiavi precedenti conservate.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--owner', required=True)
    args = parser.parse_args()
    try:
        authorize(args.source, args.destination, args.owner)
    except (OSError, ValueError, KeyError) as exc:
        parser.exit(1, f'Accesso a chiave non configurato: {exc}\n')


if __name__ == '__main__':
    main()
