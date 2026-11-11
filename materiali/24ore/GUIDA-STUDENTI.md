# AI Builder da PC a server

Questa guida accompagna il profilo 24ORE del kit. Il percorso normale parte
dal terminale del tuo computer ed entra direttamente nella VM via SSH.

## Prima della lezione

- Attiva e verifica l’account Hetzner, compreso il metodo di pagamento.
- Tieni pronto l’account Claude che userai nel corso.
- Su Windows verifica che `ssh` e `ssh-keygen` siano disponibili in PowerShell. Se mancano, installa **Client OpenSSH** dalle funzionalità facoltative di Windows; il server OpenSSH sul PC non serve.
- Tieni disponibile un’app di autenticazione per attivare la dashboard.

## Crea la chiave sul Mac

Apri **Terminale** sul Mac. La chiave del corso si chiamerà `ai_builder`, per
tenerla distinta dalle eventuali chiavi già presenti.

```bash
mkdir -p "$HOME/.ssh"
ssh-keygen -t ed25519 -f "$HOME/.ssh/ai_builder" -C "ai-builder"
```

Se il programma dice che il file esiste già e chiede di sovrascriverlo,
rispondi **n**: riusa la chiave esistente se ne conosci la passphrase.
Se scegli una passphrase, annotala nel tuo gestore di password: protegge la
chiave sul Mac ed è distinta dalla password di un server.

Copia la **chiave pubblica** negli appunti:

```bash
pbcopy < "$HOME/.ssh/ai_builder.pub"
```

Il file `ai_builder` resta sul Mac. Su Hetzner incollerai solo il contenuto
del file con estensione `.pub`.

## Crea la chiave su Windows

Apri **PowerShell** sul tuo PC, senza bisogno di avviarlo come amministratore.

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh" | Out-Null
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\ai_builder" -C "ai-builder"
```

Se chiede di sovrascrivere un file esistente, rispondi **n**. La passphrase
protegge la chiave sul tuo computer; non è una password da impostare sulla VM.

Copia la **chiave pubblica** negli appunti:

```powershell
Get-Content "$env:USERPROFILE\.ssh\ai_builder.pub" | Set-Clipboard
```

Il file `ai_builder` resta sul PC. Su Hetzner incollerai solo la chiave pubblica.

## Crea la VM su Hetzner

1. Nel progetto Hetzner apri la sezione delle chiavi SSH, aggiungi la chiave copiata e chiamala per esempio `PC corso`.
2. Crea un server con immagine ufficiale **Ubuntu 24.04**. Per la prima prova usiamo questa versione; evita immagini personalizzate o snapshot.
3. Seleziona la tua chiave nella sezione **SSH keys**.
4. Nel campo **cloud-init** incolla il contenuto del file `cloud-init-v1.0.0-rc1.yaml` fornito dal docente. Usa il file della release AI Builder indicata dal docente.
5. Associa un firewall con TCP **2222** per SSH, preferibilmente dal tuo IP, e TCP **80 e 443** da Internet per HTTPS e certificato della dashboard.
6. Attiva il backup del fornitore se previsto per la tua esercitazione e crea il server. Hetzner fattura le risorse finché esistono, anche se il server è spento.
7. Annota l’IPv4 pubblico e attendi l’installazione: vedere la VM accesa non significa che cloud-init abbia terminato.

Non devi incollare la chiave una seconda volta nel cloud-init: il kit
autorizza per `agente` le chiavi pubbliche che Hetzner ha inserito per `root`.

## Entra direttamente via SSH

Sostituisci **IP** con l’IPv4 della tua VM. Sul Mac:

```bash
ssh -i "$HOME/.ssh/ai_builder" -o IdentitiesOnly=yes -p 2222 agente@IP
```

Su Windows, in PowerShell:

```powershell
ssh -i "$env:USERPROFILE\.ssh\ai_builder" -o IdentitiesOnly=yes -p 2222 agente@IP
```

Al primo collegamento verifica l’impronta del server con il docente, poi
conferma. Può essere chiesta la passphrase della chiave; non viene richiesta
una password SSH della VM. Se nei primi minuti il collegamento non riesce,
attendi e riprova sulla 2222: il kit potrebbe essere ancora in installazione.

Gli stessi comandi con `root@IP` al posto di `agente@IP` aprono l’account
amministrativo. Nel corso lavoriamo come **agente**, anche per Claude e tmux.

## Controlla il completamento e fai il login

I prossimi comandi si scrivono **nella VM**, dopo il collegamento SSH.

```bash
sudo cloud-init status --wait
cat /var/lib/agenti-kit/stato
whoami
sudo -n whoami
claude auth login
```

`whoami` deve rispondere `agente`; il comando con `sudo` deve rispondere
`root`. Nel file di stato i passi devono essere `ok`. Durante il login Claude
apri sul tuo PC il link mostrato nel terminale e completa l’autorizzazione.

`salute` aiuta a vedere cosa manca: prima del login, dell’apertura di una
sessione e dell’attivazione della dashboard è normale che segnali quei passi.

## Apri una sessione che resta sulla VM

```bash
tmux new -s boss
cd ~/boss
claude -n boss
```

Per uscire da tmux lasciando aperta la sessione premi **Ctrl+B**, rilascia,
poi premi **D**. Ora puoi chiudere il collegamento con `exit` e chiudere il PC.
Quando rientri in SSH:

```bash
tmux attach -t boss
```

tmux mantiene la sessione quando chiudi SSH. Il programma può comunque
aspettare una tua conferma. Un riavvio della VM chiude i processi: in quel
caso riapri tmux e riprendi la conversazione con `claude -r boss`.

## Attiva la dashboard già installata

Da SSH, come `agente`, **fuori dalla schermata di Claude**, esegui:

```bash
plancia-attiva
```

Scegli una password della dashboard di almeno 12 caratteri e confermala.
Il comando mostra un codice di attivazione valido 15 minuti e l’indirizzo
HTTPS della tua dashboard. Aprilo nel browser, entra come **admin**, usa la
password scelta e il codice di attivazione, quindi collega l’app di
autenticazione e conserva i codici di recupero. Se il codice scade prima
dell’attivazione, rilancia `plancia-attiva` per prepararne uno nuovo.

Password e secondo fattore della dashboard sono separati dalla chiave SSH.
Il comando non reimposta un secondo fattore già attivo.

## Esegui il primo flusso pronto

Il kit ha già copiato un progetto con **dati fittizi**, per avere un esempio
comune prima di adattarlo al proprio lavoro.

```bash
cd ~/progetti/report-settimanale
python3 riepilogo.py
cat uscite/riepilogo.md
```

Risultato iniziale: **5 attività**, di cui **3 aperte**, **1 in corso** e
**1 completata**; **2 priorità alte ancora da chiudere**. Questo programma
non usa un modello AI: è l’opzione pronta da eseguire, controllare e poi
modificare con Claude. Per lavorarci con Claude apri una nuova sessione:

```bash
tmux new -s report -c ~/progetti/report-settimanale
claude -n report
```

## Programma e controlla il flusso

Il timer è predisposto ma spento. Prima verifica il risultato manuale; poi,
da una shell della VM come `agente`:

```bash
systemctl --user daemon-reload
systemctl --user start report-corso.service
systemctl --user enable --now report-corso.timer
systemctl --user list-timers report-corso.timer
```

L’orario iniziale è dal lunedì al venerdì alle **08:30**, fuso italiano.
Concorda con Claude l’orario adatto al tuo lavoro prima di attivarlo.
Il timer esegue il programma pronto e non richiede un abbonamento AI a ogni
esecuzione. La dashboard mostra le sessioni tmux; l’esito di questo servizio
si verifica nel suo registro e nel file prodotto.

```bash
journalctl --user -u report-corso.service -n 30 --no-pager
systemctl --user disable --now report-corso.timer
```

Il primo comando mostra il registro; il secondo interrompe la programmazione.
Un’esecuzione già partita si ferma con `systemctl --user stop report-corso.service`.

## Se qualcosa non va

- **Connection refused o timeout:** verifica IP, completamento dell’installazione e firewall TCP 2222; la porta 22 non è quella del corso.
- **Permission denied (publickey):** verifica che `-i` indichi la chiave privata sul PC e che la corrispondente chiave pubblica sia stata selezionata alla creazione. Non caricare la chiave privata sulla VM.
- **La dashboard non si apre:** verifica `plancia-attiva`, `sudo systemctl status session-board --no-pager`, firewall TCP 80 e 443 e `sudo journalctl -u caddy -n 30 --no-pager`.
- **tmux non trova boss dopo un riavvio:** crea una nuova sessione, entra in `~/boss` e usa `claude -r boss`.
- **Il kit segnala da-completare:** leggi `sudo tail -n 60 /var/log/agenti-kit-install.log`. Il docente può rilanciarlo con `sudo bash /opt/agenti-kit/install.sh`; il profilo 24ORE viene ricordato.

## Riferimenti

- [Chiavi in Windows OpenSSH](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement)
- [Generazione delle chiavi SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- [SSH su Hetzner](https://docs.hetzner.com/cloud/servers/getting-started/connecting-to-the-server/)
- [tmux](https://github.com/tmux/tmux/wiki/Getting-Started)
