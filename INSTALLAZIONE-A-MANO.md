# Installare il kit a mano

Il modo normale di installare il kit è il cloud-init: incolli un testo
quando crei il server e la macchina fa da sola. Questa pagina serve quando
quella strada non c'è: il fornitore non ha il campo cloud-init, la macchina
esiste già, oppure il cloud-init non è partito.

Il risultato è lo stesso. Cambia solo chi lancia i comandi: tu, da root,
uno alla volta.

## 1. Cosa serve

- Una macchina con **Ubuntu 24.04**, appena creata. Su una macchina già
  usata il kit non cancella niente di tuo, ma cambia SSH (vedi il punto 5):
  leggi tutto prima di cominciare.
- L'accesso come **root**: dalla console del fornitore, oppure in SSH.
- Dieci minuti.

Dove lanciare i comandi: se puoi, **in SSH da root**, perché lì il testo si
incolla. Nella console web di Hetzner il testo incollato arriva rovinato
nei simboli: i comandi qui sotto andrebbero scritti a mano.

## 2. Il firewall, prima di tutto

Nel pannello del fornitore, il firewall della macchina non deve lasciare
entrare niente, a parte la porta che stai usando tu adesso per SSH, se
entri da lì. Una macchina con un indirizzo pubblico e il firewall aperto è
la porta di casa lasciata aperta.

## 3. Scaricare il kit e controllarlo

Apri la pagina delle release,
https://github.com/tommasinigiovanni/alleniamoimprese-agenti-kit/releases,
e prendi la versione più recente che non sia marcata "Pre-release". Nella
sua pagina trovi il numero di versione e l'**impronta dell'archivio**, una
fila di 64 lettere e numeri.

Scrivi la versione in una variabile, così i comandi dopo la usano:

```bash
VERSIONE=v1.3
```

Scarica l'archivio:

```bash
cd /root
curl -fsSL -o kit.tar.gz https://github.com/tommasinigiovanni/alleniamoimprese-agenti-kit/releases/download/$VERSIONE/alleniamoimprese-agenti-kit-$VERSIONE.tar.gz
```

Se `curl` non c'è: `apt-get update` e poi
`apt-get install -y curl ca-certificates`.

Calcola l'impronta di quello che hai scaricato:

```bash
sha256sum kit.tar.gz
```

Confronta la fila che vedi con quella della pagina della release. Devono
essere **uguali, carattere per carattere**. Se non lo sono, fermati:
l'archivio non è quello pubblicato. Cancellalo (`rm kit.tar.gz`) e
riprova il download.

## 4. Installare

Estrai l'archivio e lancia l'installazione:

```bash
rm -rf /opt/agenti-kit
tar -xzf kit.tar.gz -C /opt --no-same-owner
bash /opt/agenti-kit/install.sh
```

Ci mette qualche minuto: installa i programmi, crea l'utente `agente`,
prepara la console. Scrive a schermo un passo alla volta. Alla fine deve
dire:

```
=== Installazione completa.
```

Se invece dice "Installazione finita con passi da completare", vai al
punto 8.

Se eri in SSH e la connessione cade durante l'installazione (il kit
sposta SSH sulla porta 2222 proprio in questo passo), non è un guasto:
rientra dalla console web del fornitore e rilancia
`bash /opt/agenti-kit/install.sh`. Riparte da dove serve.

## 5. Subito dopo: la password di agente

**Non chiudere la finestra da root prima di questo passo.** Il kit ha
appena cambiato SSH:

- la porta non è più la 22, è la **2222**;
- **root da SSH non entra più**;
- entra solo `agente`, con la sua password. E `agente` una password ancora
  non ce l'ha.

Quindi, finché sei root, dagliela:

```bash
passwd agente
```

Lunga, solo lettere e numeri. È la password con cui entrerai in SSH e con
cui userai `sudo`.

Se chiudi prima di averlo fatto non hai perso niente: rientri dalla
console web del fornitore, che funziona sempre, e lo fai da lì (`su -`,
poi `passwd agente`).

## 6. Rientrare come agente

1. Nel firewall del pannello apri in ingresso la porta **TCP 2222**, meglio
   se solo verso il tuo indirizzo IP. Se avevi aperto la 22, richiudila:
   non risponde più nessuno.
2. Dal tuo computer:

```bash
ssh -p 2222 agente@INDIRIZZO-DELLA-MACCHINA
```

3. Controlla la macchina:

```bash
salute
```

Deve dire `[OK]` su tutto tranne due righe, che sono giuste così: il login
di Claude e il boss, che non hai ancora fatto.

## 7. Il login e il boss

Da qui in poi è uguale a chi ha usato il cloud-init:

```bash
qr-login-claude
tmux new -s boss
cd boss
claude -n boss --rc
```

`aiuto` rivede il promemoria dei comandi. Per uscire da tmux lasciando
tutto acceso: Ctrl+B, poi D.

## 8. Se qualcosa non va

- **"install.sh va lanciato come root".** Non sei root: `su -` dalla
  console, oppure `sudo -i` se il tuo utente può.
- **L'installazione finisce con passi da completare.** Il nome dei passi è
  scritto in fondo, e in `/var/lib/agenti-kit/stato`. Il dettaglio è in
  `/var/log/agenti-kit-install.log`: cerca le righe che cominciano con
  `!!!`. Quasi sempre è la rete che è caduta durante un download:
  rilancia `bash /opt/agenti-kit/install.sh`. Si può rilanciare quante
  volte vuoi: ogni passo controlla cosa c'è già.
- **Il passo `ssh` resta da completare.** Vuol dire che SSH non ascolta
  sulla 2222. Guarda `ss -ltn` e le ultime righe del registro, e scrivilo
  nello spogliatoio con quello che vedi.
- **Non riesci più a entrare in SSH.** La console web del fornitore
  funziona sempre: entri da lì come `agente` senza password, o come root
  con la sua. Controlla nell'ordine: `agente` ha una password? La 2222 è
  aperta nel firewall? Stai usando `-p 2222`?
- **Non è Ubuntu 24.04.** Il kit è provato solo lì. Su altre versioni può
  funzionare, ma nessuno l'ha visto.

## 9. Cosa ha fatto l'installazione

L'elenco completo è nel [README](README.md), alla voce "Cosa fa". In
breve: fuso orario italiano e aggiornamenti di sicurezza; tastiera
italiana nella console; l'utente `agente`; SSH sulla 2222 con la password;
`sudo` con la password e `installa` senza; Claude Code, Codex, tmux, git,
Syncthing, python3-venv; le cartelle `boss`, `progetti`, `segreti`; i
comandi `salute`, `qr-login-claude`, `qr-login-codex`, `installa`, `aiuto`.

Il kit non scrive nessuna password, né di root né di `agente`, e non apre
nessuna porta nel firewall del fornitore: quelle le decidi tu.
