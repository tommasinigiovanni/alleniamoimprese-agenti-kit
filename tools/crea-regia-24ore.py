#!/usr/bin/env python3
"""Genera la regia HTML offline da REGIA.md, senza dipendenze Python.

Uso: python3 tools/crea-regia-24ore.py [--font percorso/Manrope-var.ttf]
Il font opzionale viene incorporato; senza opzione usa Manrope se installato,
altrimenti Arial. I contenuti e i comandi restano in REGIA.md.
"""
import argparse
import base64
from html import escape
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'materiali/24ore'


def inline(text):
    text = escape(text)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    text = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\[([^\]]+)\]\((https?://[^\s)]+)\)', r'<a href="\2" target="_blank" rel="noopener">\1</a>', text)
    return text


def render(lines):
    output, paragraph, code = [], [], None
    listing = None

    def flush():
        if paragraph:
            output.append('<p>' + inline(' '.join(paragraph)) + '</p>')
            paragraph.clear()

    def close_list():
        nonlocal listing
        if listing:
            output.append(f'</{listing}>')
            listing = None

    for line in lines + ['']:
        if line.startswith('```'):
            if code is None:
                flush(); close_list(); code = []
            else:
                output.append('<div class="command"><button class="copy" type="button">Copia</button><pre><code>' + escape('\n'.join(code)) + '</code></pre></div>')
                code = None
            continue
        if code is not None:
            code.append(line)
            continue
        if not line.strip():
            flush(); close_list(); continue
        if line.startswith('### '):
            flush(); close_list()
            heading = line[4:]
            start = re.match(r'(\d+)[–-]', heading)
            output.append(f'<h3 data-minute="{start.group(1) if start else ""}">' + inline(heading) + '</h3>')
        elif line.startswith('> '):
            flush(); close_list()
            output.append('<blockquote>' + inline(line[2:]) + '</blockquote>')
        elif line.startswith('- ') or re.match(r'^\d+\. ', line):
            flush()
            kind = 'ul' if line.startswith('- ') else 'ol'
            if listing != kind:
                close_list(); output.append(f'<{kind}>'); listing = kind
            content = line[2:] if kind == 'ul' else re.sub(r'^\d+\. ', '', line)
            output.append('<li>' + inline(content) + '</li>')
        else:
            close_list(); paragraph.append(line.strip())
    if code is not None:
        raise ValueError('Blocco di codice non chiuso')
    return '\n'.join(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path)
    args = parser.parse_args()
    lines = (DEST/'REGIA.md').read_text().splitlines()
    sections = []
    for line in lines:
        if line.startswith('## '):
            sections.append((line[3:], []))
        elif sections:
            sections[-1][1].append(line)
    assert len(sections) == 5
    buttons = ''.join(f'<button type="button" data-tab="s{i}">{escape(title)}</button>' for i,(title,_) in enumerate(sections))
    bodies = ''.join(f'<section id="s{i}" hidden><h2>{escape(title)}</h2>{render(body)}</section>' for i,(title,body) in enumerate(sections))
    font = ''
    if args.font:
        font = '@font-face{font-family:Manrope;src:url(data:font/ttf;base64,' + base64.b64encode(args.font.read_bytes()).decode() + ') format("truetype");font-weight:200 800}'
    html = TEMPLATE.replace('{FONT}',font).replace('{BUTTONS}',buttons).replace('{BODIES}',bodies)
    (DEST/'regia.html').write_text(html)
    print('Regia offline generata:', DEST/'regia.html')


TEMPLATE = '''<!doctype html>
<html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AI Builder · Regia delle lezioni</title><style>{FONT}
:root{--petrolio:#173D3C;--avorio:#F4F1E9;--ruggine:#B64B2E;--inchiostro:#182322;--sabbia:#DDD5C5;--salvia:#536963}
*{box-sizing:border-box}body{margin:0;background:var(--avorio);color:var(--inchiostro);font:400 17px/1.65 Manrope,Arial,sans-serif}header{position:sticky;top:0;z-index:2;background:var(--petrolio);color:var(--avorio);padding:18px 30px}h1{font-size:25px;font-weight:600;margin:0}header p{margin:3px 0 12px;font-size:13px}nav{display:flex;gap:7px;flex-wrap:wrap}button,a.button{font:500 14px Manrope,Arial,sans-serif;cursor:pointer;border-radius:7px;padding:10px 13px;border:1px solid var(--sabbia);background:var(--avorio);color:var(--petrolio);text-decoration:none}nav button{background:transparent;color:var(--avorio);border-color:#708583}nav button[aria-selected=true]{background:var(--avorio);color:var(--petrolio)}main{max-width:1450px;margin:auto;display:grid;grid-template-columns:minmax(0,880px) 310px;gap:42px;padding:26px 32px}h2{font-size:30px;line-height:1.3;font-weight:600;color:var(--petrolio);margin:5px 0 27px}h3{font-size:23px;line-height:1.4;font-weight:600;color:var(--petrolio);margin:40px 0 14px;padding-top:14px;border-top:1px solid var(--sabbia);scroll-margin-top:170px}p{margin:13px 0}blockquote{margin:20px 0;padding:15px 20px;border-left:4px solid var(--ruggine);background:#ebe6db;font-size:20px;line-height:1.65}li{margin:8px 0}a{color:var(--petrolio);text-underline-offset:3px}code{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:.9em}p code,li code{background:var(--sabbia);padding:1px 4px;border-radius:3px}.command{position:relative;background:var(--petrolio);color:var(--avorio);border-radius:9px;margin:18px 0}.command pre{margin:0;padding:54px 20px 20px;overflow-x:auto;line-height:1.6}.copy{position:absolute;right:9px;top:8px;padding:5px 11px;font-size:12px}aside{position:sticky;top:165px;align-self:start;border:1px solid var(--sabbia);border-radius:12px;padding:20px;font-size:14px}aside h2{font-size:19px;margin-bottom:10px}.clock{font-size:46px;font-weight:600;font-variant-numeric:tabular-nums;color:var(--petrolio)}.clock.over{color:var(--ruggine)}.timer-buttons{display:flex;gap:7px}aside p{color:var(--salvia)}aside .button{display:block;margin:9px 0;text-align:center}.schema{width:100%;height:auto;margin-top:16px;cursor:zoom-in}#schema-dialog{width:96vw;max-width:1920px;border:0;background:var(--avorio);padding:18px}#schema-dialog img{width:100%}#schema-dialog::backdrop{background:#182322cc}footer{border-top:1px solid var(--sabbia);padding:25px 32px;font-size:12px;color:var(--salvia)}[hidden]{display:none!important}@media(max-width:950px){main{grid-template-columns:1fr;padding:20px}aside{position:static;grid-row:1}header{position:static}blockquote{font-size:18px}}@media print{header,aside,footer,.copy{display:none}main{display:block;padding:0}section[hidden]{display:block!important}section{break-before:page}blockquote{break-inside:avoid}}
</style></head><body>
<header><h1>AI Builder · Regia delle lezioni</h1><p>Giovanni Tommasini · 24ORE Business School · quattro incontri da 60 minuti</p><nav aria-label="Lezioni">{BUTTONS}</nav></header>
<main><article>{BODIES}</article><aside><h2>Tempo della lezione</h2><div id="clock" class="clock" role="timer">00:00</div><div class="timer-buttons"><button id="start" type="button">Avvia</button><button id="reset" type="button">Azzera</button></div><p>Il timer è locale a questa finestra. Cambiare lezione non lo azzera.</p><a class="button" href="GUIDA-STUDENTI.md" target="_blank">Guida studenti</a><a class="button" href="REGIA.md" target="_blank">Testo della regia</a><button id="show-schema" type="button">Apri schema PC e server</button><img class="schema" src="pc-server-tmux.png" alt="Il PC si collega via SSH alla VM, dove tmux mantiene la sessione Claude Code"><p>Accesso: porta 2222, stessa chiave per root e agente. Lavoro quotidiano: agente.</p><p>La prova Hetzner e HTTPS va completata prima della diretta. Hindsight rimane da collaudare.</p></aside></main>
<dialog id="schema-dialog"><button id="close-schema" type="button">Chiudi</button><img src="pc-server-tmux.png" alt="Schema PC e server"></dialog>
<footer>Regia 24ORE dedicata. Sorgente: REGIA.md. La regia dell’edizione Alleniamo Imprese conserva i propri testi.</footer>
<script>
let selected='s1';function selectTab(id){if(!document.getElementById(id))return;selected=id;document.querySelectorAll('article section').forEach(s=>s.hidden=s.id!==id);document.querySelectorAll('[data-tab]').forEach(b=>b.setAttribute('aria-selected',String(b.dataset.tab===id)));try{localStorage.setItem('regia24ore-tab',id)}catch(e){}window.scrollTo(0,0)}
document.querySelectorAll('[data-tab]').forEach(b=>b.addEventListener('click',()=>selectTab(b.dataset.tab)));try{selected=localStorage.getItem('regia24ore-tab')||'s1'}catch(e){}selectTab(selected);
document.querySelectorAll('.copy').forEach(b=>b.addEventListener('click',async()=>{let value=b.parentElement.querySelector('code').textContent;try{await navigator.clipboard.writeText(value)}catch(e){const field=document.createElement('textarea');field.value=value;document.body.append(field);field.select();document.execCommand('copy');field.remove()}b.textContent='Copiato';setTimeout(()=>b.textContent='Copia',1200)}));
let elapsed=0,started=null;const clock=document.getElementById('clock');function tick(){const seconds=Math.floor((elapsed+(started===null?0:Date.now()-started))/1000);clock.textContent=String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');clock.classList.toggle('over',seconds>=3600)}setInterval(tick,250);document.getElementById('start').onclick=function(){if(started===null){started=Date.now();this.textContent='Pausa'}else{elapsed+=Date.now()-started;started=null;this.textContent='Riprendi'}tick()};document.getElementById('reset').onclick=()=>{elapsed=0;started=null;document.getElementById('start').textContent='Avvia';tick()};const dialog=document.getElementById('schema-dialog');document.getElementById('show-schema').onclick=()=>dialog.showModal();document.querySelector('.schema').onclick=()=>dialog.showModal();document.getElementById('close-schema').onclick=()=>dialog.close();
</script></body></html>'''

if __name__ == '__main__':
    main()
