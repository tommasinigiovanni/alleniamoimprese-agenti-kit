#!/usr/bin/env python3
"""Esempio pronto: riepilogo di attività fittizie, senza API o servizi esterni."""
from collections import Counter
import csv
from datetime import datetime
from pathlib import Path


def main():
    root = Path(__file__).resolve().parent
    with (root / 'attivita.csv').open(newline='', encoding='utf-8') as handle:
        reader = csv.DictReader(handle)
        if not {'titolo', 'responsabile', 'stato', 'priorita'}.issubset(reader.fieldnames or []):
            raise ValueError('Mancano le colonne previste in attivita.csv')
        rows = list(reader)
    allowed = {'aperto', 'in corso', 'completato'}
    if any(row['stato'] not in allowed for row in rows):
        raise ValueError('Uno stato non è valido: usare aperto, in corso o completato')
    counts = Counter(row['stato'] for row in rows)
    priorities = [row for row in rows if row['stato'] != 'completato' and row['priorita'] == 'alta']
    lines = ['# Riepilogo delle attività', '', '**Dati fittizi per il corso AI Builder.**', '',
             f'Generato: {datetime.now().astimezone().isoformat(timespec="seconds")}', '',
             f'Attività totali: {len(rows)}.',
             f'Aperte: {counts["aperto"]}. In corso: {counts["in corso"]}. Completate: {counts["completato"]}.', '',
             '## Priorità alte ancora da chiudere', '']
    lines += [f'- {row["titolo"]} · {row["responsabile"]}' for row in priorities] or ['Nessuna.']
    output = root / 'uscite'
    output.mkdir(exist_ok=True)
    (output / 'riepilogo.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'Creato {output / "riepilogo.md"}: {len(rows)} attività, {len(priorities)} priorità alte aperte.')


if __name__ == '__main__':
    main()
