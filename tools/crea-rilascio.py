#!/usr/bin/env python3
"""Crea l'archivio della release, la sua impronta e il testo di cloud-init.

Uso: python3 tools/crea-rilascio.py v0.1

Scrive in dist/:
- alleniamoimprese-agenti-kit-VERSIONE.tar.gz, l'archivio che scarica la macchina;
- alleniamoimprese-agenti-kit-VERSIONE.tar.gz.sha256, la sua impronta;
- cloud-init-VERSIONE.yaml, il testo da incollare alla creazione del server.

L'archivio è riproducibile: con gli stessi file esce la stessa impronta.
"""

import gzip
import hashlib
import io
import sys
import tarfile
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
REPOSITORY = "tommasinigiovanni/alleniamoimprese-agenti-kit"
CONTENUTO = ["install.sh", "bin", "systemd", "console"]
DATA_FISSA = 1767225600  # 2026-01-01, per un archivio sempre uguale
LIMITE_CLOUD_INIT = 32 * 1024  # il massimo che accetta Hetzner


def voci(versione):
    """Elenco ordinato di (percorso nell'archivio, contenuto o None, permessi)."""
    elenco = [("agenti-kit", None, 0o755)]
    for nome in CONTENUTO:
        percorso = RADICE / nome
        if percorso.is_dir():
            elenco.append((f"agenti-kit/{nome}", None, 0o755))
            for file in sorted(percorso.rglob("*")):
                if file.is_file() and file.name != ".DS_Store":
                    relativo = file.relative_to(RADICE).as_posix()
                    permessi = 0o755 if nome == "bin" else 0o644
                    elenco.append((f"agenti-kit/{relativo}", file.read_bytes(), permessi))
        else:
            elenco.append((f"agenti-kit/{nome}", percorso.read_bytes(), 0o755))
    elenco.append(("agenti-kit/VERSIONE", f"{versione}\n".encode(), 0o644))
    return sorted(elenco, key=lambda voce: voce[0])


def archivio(versione):
    tar_grezzo = io.BytesIO()
    with tarfile.open(fileobj=tar_grezzo, mode="w", format=tarfile.GNU_FORMAT) as tar:
        for nome, contenuto, permessi in voci(versione):
            info = tarfile.TarInfo(nome)
            info.mtime = DATA_FISSA
            info.uid = info.gid = 0
            info.uname = info.gname = "root"
            info.mode = permessi
            if contenuto is None:
                info.type = tarfile.DIRTYPE
                tar.addfile(info)
            else:
                info.size = len(contenuto)
                tar.addfile(info, io.BytesIO(contenuto))
    compresso = io.BytesIO()
    with gzip.GzipFile(filename="", mode="wb", fileobj=compresso, compresslevel=9, mtime=0) as gz:
        gz.write(tar_grezzo.getvalue())
    return compresso.getvalue()


def main():
    if len(sys.argv) != 2 or not sys.argv[1].startswith("v"):
        sys.exit("Uso: python3 tools/crea-rilascio.py v0.1")
    versione = sys.argv[1]
    dist = RADICE / "dist"
    dist.mkdir(exist_ok=True)

    nome = f"alleniamoimprese-agenti-kit-{versione}.tar.gz"
    dati = archivio(versione)
    impronta = hashlib.sha256(dati).hexdigest()
    (dist / nome).write_bytes(dati)
    (dist / f"{nome}.sha256").write_text(f"{impronta}  {nome}\n")

    modello = (RADICE / "tools" / "cloud-init.modello.yaml").read_text()
    testo = (modello.replace("{VERSIONE}", versione)
                    .replace("{IMPRONTA}", impronta)
                    .replace("{REPOSITORY}", REPOSITORY))
    if "{" in testo:
        sys.exit("Nel testo di cloud-init è rimasto un segnaposto.")
    if len(testo.encode()) > LIMITE_CLOUD_INIT:
        sys.exit("Il testo di cloud-init supera i 32 KiB di Hetzner.")
    (dist / f"cloud-init-{versione}.yaml").write_text(testo)

    print(f"Archivio: dist/{nome} ({len(dati)} byte)")
    print(f"Impronta: {impronta}")
    print(f"Cloud-init: dist/cloud-init-{versione}.yaml ({len(testo.encode())} byte)")


if __name__ == "__main__":
    main()
