# AI Builder regia delle quattro lezioni

Una regia dedicata a 24ORE Business School, in quattro incontri da 60 minuti.
Ogni lezione aggiunge un risultato allo stesso progetto. Il pacchetto pronto
permette di partire; il ragionamento serve a capire cosa cambiare e come
verificare che funzioni. Date dei singoli incontri da inserire con il calendario
docenti. Le frasi tra virgolette sono tracce per il parlato.

## Preparazione

### Prima della prima diretta

- Apri `regia.html` sul secondo monitor e tieni aperta la guida studenti.
- Usa il [nuovo repository studenti](https://github.com/tommasinigiovanni/24orebs-ai-builder-kit): la release corrente è **v1.0.0-rc1**, con file `cloud-init-v1.0.0-rc1.yaml`. Il bootstrap punta al nuovo repository pubblico e la sua impronta è verificata. I vecchi cloud-init v1.7-24ore e Alleniamo Imprese rimangono nell’archivio e non sono quelli da distribuire.
- Fai una prova su VM Hetzner nuova: chiave selezionata alla creazione, ingresso `agente` e `root` sulla 2222, nessun ingresso con password, certificato HTTPS, attivazione MFA e dashboard visibile dal PC.
- Nella tua VM prepara una sessione `demo`, senza dati aziendali o credenziali sullo schermo. Risolvi il login Claude e le autorizzazioni prima della demo.
- Prova il lavoro di 30–40 secondi, chiudi SSH e rientra. La VM rimane accesa.
- Tieni una copia pulita dell’esempio con dati fittizi, una sessione pronta e una schermata del risultato atteso per chi rimane fermo sul provisioning.
- Chiedi prima dell’incontro account Hetzner verificato, account Claude pronto e OpenSSH Client disponibile su Windows.

### Cosa è già automatico

Il cloud-init prepara utente `agente`, chiavi per entrambi gli utenti, SSH
2222 senza password, tmux, Claude Code e dashboard. Il partecipante fa il login
Claude e attiva password e secondo fattore della dashboard. La console Hetzner
serve solo per diagnosi o recupero. Claude lavora come `agente`; `sudo` gli
permette gli interventi amministrativi, con la conferma prevista dal kit.

### Memoria e moduli degli altri docenti

Per il percorso base usa la memoria del progetto su file, già leggibile da
Claude in una nuova sessione. **Hindsight è un’integrazione ancora da collaudare**:
non mostrarla come inclusa nel pacchetto attuale. Un eventuale approfondimento
entra dopo la prova di provider, credenziali, risorse e recupero.
Il caso `report-settimanale` è un esempio comune con dati fittizi. Collega
istruzioni e criteri di qualità al lavoro fatto con Federico e dati e controlli
al modulo di Mirco; la sostituzione con un caso condiviso va allineata tra docenti.

## L1 La macchina e il primo lavoro

### 0–10 Due computer e una sessione che resta

Mostra lo schema `pc-server-tmux.png`. Parti dalle domande «posso chiudere il
Mac?» e «se cambio computer, dov’è il lavoro?».

> Abbiamo due computer. Il primo è sulla vostra scrivania. Il secondo è la macchina virtuale nel datacenter. La VM ha i suoi programmi e i suoi file. Rimane accesa anche quando voi chiudete il portatile.

> Sul PC useremo Claude Code con l’interfaccia grafica per il lavoro locale. Sulla VM useremo Claude Code da terminale. Nel nostro corso Ubuntu Server è senza ambiente grafico.

> SSH è il collegamento. tmux tiene aperta la sessione sulla VM. Claude Code è il programma che lavora dentro quella sessione.

Nei primi otto minuti distribuisci circa due minuti a coppie di computer,
interfacce, SSH e tmux. Negli ultimi due mostra il rientro nella sessione
della tua VM, dopo aver chiuso SSH. Mostra il file prodotto nel frattempo.
La demo è tua: le VM dei partecipanti si creano dopo.

### 10–20 La chiave sul proprio computer

Mostra Terminale su Mac e PowerShell su Windows. Usa i comandi della guida:
nome dedicato `ai_builder`, niente sovrascrittura di una chiave esistente.

> La chiave privata rimane sul vostro computer. Copiamo la pubblica: è quella che il server userà per riconoscervi. Se scegliete una passphrase, protegge la chiave sul PC; non è una password del server.

Mac, poi copia la pubblica:

```bash
ssh-keygen -t ed25519 -f "$HOME/.ssh/ai_builder" -C "ai-builder"
pbcopy < "$HOME/.ssh/ai_builder.pub"
```

Windows, dopo aver creato `.ssh` come nella guida:

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\ai_builder" -C "ai-builder"
Get-Content "$env:USERPROFILE\.ssh\ai_builder.pub" | Set-Clipboard
```

### 20–30 Creazione della VM

Chiave in Hetzner, immagine ufficiale Ubuntu 24.04, cloud-init **24ORE**,
firewall 2222 per SSH e 80/443 per HTTPS, IPv4 annotato. Account e pagamento
devono essere già verificati. Spiega la scelta delle porte mentre parte
l’installazione.

> Il cloud-init è la preparazione che facciamo fare alla macchina. La chiave è il modo in cui ci riconosce. Li scegliamo entrambi alla creazione.

### 30–40 Ingresso diretto e verifica

Mostra il comando con `-i` e `-p 2222`, diverso solo nel percorso della chiave
tra Mac e Windows. Dopo l’ingresso controlla il completamento: una VM accesa
può essere ancora in installazione.

```bash
sudo cloud-init status --wait
cat /var/lib/agenti-kit/stato
whoami
sudo -n whoami
```

> Entriamo come agente. Quando serve un intervento da amministratore, usiamo sudo. La stessa chiave ci permette anche di entrare come root, ma Claude e le sue sessioni lavorano come agente.

Se qualcuno è fermo sull’account o sul provisioning, prosegui sulla tua VM e
fagli seguire il ragionamento. Recupera l’attivazione con la guida; non
trasformare il resto della live nel debug di un solo account.

### 40–50 Login e prima sessione

```bash
claude auth login
tmux new -s boss
cd ~/boss
claude -n boss
```

Fai dire a Claude dove si trova, con quale utente lavora e quali cartelle del
progetto vede. Esci con Ctrl+B, poi D; rientra con `tmux attach -t boss`.

> Il file sul vostro Mac e il file sulla VM sono due file su due computer diversi. Il collegamento SSH non li sincronizza automaticamente.

### 50–60 Primo risultato e dashboard

Esegui l’esempio pronto, leggi l’output e confrontalo con il risultato atteso.

```bash
cd ~/progetti/report-settimanale
python3 riepilogo.py
cat uscite/riepilogo.md
```

> Abbiamo cinque attività: tre aperte, una in corso, una completata. Due priorità alte ancora da chiudere. Prima di personalizzare il flusso, sappiamo riconoscere un risultato corretto.

Mostra `plancia-attiva` dalla tua shell SSH. Oscura password, codice di
attivazione e QR durante la condivisione; spiega che ciascuno farà la propria
attivazione. Se il provisioning ha preso più tempo, questa è la consegna
guidata da completare dopo la lezione.

Compito: completare dashboard, rientrare nella sessione da un secondo
collegamento e verificare l’esempio. Portare una sola modifica utile al
proprio lavoro e il criterio con cui valutarla.

## L2 Dal primo risultato al lavoro ricorrente

### 0–10 Controllo del risultato

Apri la dashboard, ritrova le sessioni e il progetto. Chiedi a un partecipante
che cosa ha verificato nel report, non soltanto se il programma è partito.

> Funziona significa che produce il risultato che ci serve, con i dati giusti. Una finestra aperta non dimostra che il lavoro sia finito.

### 10–25 Una modifica con Claude

Apri una sessione nel progetto `report-settimanale`. Prima esegui il programma
pronto senza modifiche; poi chiedi una sola personalizzazione, per esempio
raggruppare le attività aperte per responsabile. Usa i criteri del modulo
di Federico e i controlli sui dati di Mirco.

> Dì a Claude il risultato atteso, quali dati deve usare e come lo controlleremo. Non serve progettare tutto il sistema in una richiesta.

Prova base: CSV e conteggi controllabili. Approfondimento: sostituire i dati
fittizi con un campione autorizzato e minimizzato del proprio caso, conservando
una copia dell’esempio per il confronto.

### 25–40 Esecuzione programmata

Il kit contiene già servizio e timer, spento. Mostra prima una partenza manuale,
poi abilita l’orario predisposto. Tutti questi comandi sono nella VM come agente.

```bash
systemctl --user daemon-reload
systemctl --user start report-corso.service
systemctl --user enable --now report-corso.timer
systemctl --user list-timers report-corso.timer
```

> tmux mantiene una sessione. Il timer fa partire un programma a un orario. Sono due compiti diversi.

Il timer esegue il programma Python pronto, senza richiamare Claude a ogni
esecuzione. Una futura esecuzione AI non interattiva richiede autenticazione,
permessi, consumi e gestione degli errori propri: non basta programmare un
comando Claude interattivo.

### 40–50 Esito e arresto

```bash
journalctl --user -u report-corso.service -n 30 --no-pager
systemctl --user disable --now report-corso.timer
systemctl --user stop report-corso.service
```

Mostra l’ora dell’output e il registro. Fai arrestare la programmazione, poi
riattivarla solo a chi vuole mantenerla. Le notifiche esterne sono un’estensione
da configurare con il proprio account; Telegram non è incluso nell’esempio base.

### 50–60 Prova di errore e consegna

Su una copia del CSV scrivi uno stato non valido. Esegui il programma e mostra
l’errore, poi ripristina il dato. Non produrre un report apparentemente valido
ignorando l’errore. Compito: una personalizzazione, una prova corretta e una
prova con input non valido, con risultato e registro da mostrare.

## L3 Memoria del progetto e controllo delle modifiche

### 0–10 Ripartire da una sessione nuova

Fai chiudere una conversazione dopo aver scritto uno stato del lavoro.
Aprine un’altra nella stessa cartella e chiedi a Claude cosa sa del progetto.

> La conversazione non è l’unico posto in cui tenere il lavoro. Nel progetto lasciamo istruzioni, decisioni e uno stato leggibile quando ricominciamo.

### 10–25 Istruzioni e memoria su file

Mostra `CLAUDE.md`, `STATO.md` e l’output. Distingui le istruzioni stabili dai
fatti aggiornati: risultato, prova eseguita, problema aperto, prossimo passo.

> Una memoria utile ci permette di recuperare un’informazione e correggerla. Se non so da dove arriva o come aggiornarla, rischio di conservare un errore.

Esercizio: cambiare una regola del report, aggiornare lo stato e verificare
che una sessione nuova legga la regola corretta. Hindsight resta un eventuale
approfondimento dopo un collaudo dedicato, con provider e costi espliciti.

### 25–45 Salvare una versione verificata

Spiega la differenza fra copia della VM e versione del progetto. Inizializza
un repository locale e salva solo script, istruzioni e dati fittizi.

```bash
cd ~/progetti/report-settimanale
git init
printf 'uscite/\n.env\n' > .gitignore
git add riepilogo.py attivita.csv CLAUDE.md STATO.md .gitignore
git status
```

Prima del commit ogni partecipante imposta la propria identità Git, guidato
da Claude, poi salva una versione con un messaggio leggibile. GitHub privato
è un passo successivo con autenticazione personale: non incollare token nella
conversazione né includere dati riservati nel repository.

### 45–60 Una modifica reversibile

Fai cambiare una regola a Claude, verifica l’output e osserva la differenza.
Se la modifica non va bene, torna alla versione precedente dopo aver mostrato
cosa verrà perso. Compito: versione verificata e stato del progetto aggiornato,
con una decisione e la fonte o la prova che la giustifica.

## L4 Ripartenza e prova del proprio sistema

### 0–15 Chiudere SSH e riavviare sono due cose diverse

Riprendi la paura «e se si rompe il Mac?». Il lavoro remoto resta sulla VM;
la perdita del PC richiede comunque un modo autorizzato per accedere di nuovo.
Mostra una disconnessione e, sulla tua VM di prova, un riavvio già collaudato.

> Chiudere SSH lascia tmux aperto. Riavviare il server chiude i processi. I file restano sul disco e i servizi predisposti possono ripartire.

Verifica dashboard e timer. Riapri tmux e riprendi la conversazione con
`claude -r boss`. Non promettere che tmux sopravviva al riavvio.

### 15–30 Cosa conservare per ripartire

Mostra il progetto fuori dalla VM e il backup del fornitore. Nel recupero della
dashboard servono insieme database MFA, chiave di cifratura e marker; un backup
parziale non basta. Le chiavi private SSH restano conservate sul PC e nel
backup personale protetto del partecipante, non nel repository del progetto.

> Un repository conserva le versioni del progetto. Un backup conserva quello che abbiamo scelto di includere. La prova che conta è riuscire a recuperarlo.

La ricostruzione su una nuova VM si mostra con un esempio già provato dal docente.
Creazione account, certificati e reinserimento delle credenziali non hanno una
durata garantita. Nessuna cancellazione della VM originale durante la live.

### 30–50 Prova del progetto

Ogni partecipante mostra: input, comando o avvio, risultato, criterio di qualità,
prova di errore e modo di fermarlo. Usa pochi esempi in live e raccolta delle
altre prove come consegna; l’eventuale presentazione finale comune del corso
ha il suo appuntamento con gli altri docenti.

> Non serve mostrare quanti strumenti avete collegato. Mostrate un lavoro che sapete far partire, controllare, fermare e riprendere.

### 50–60 Consegna e prossimi passi

Controlla progetto e istruzioni conservati, accessi personali recuperabili,
programmazione consapevolmente attiva o spenta, costi delle risorse compresi.
Segna il prossimo miglioramento con un risultato atteso e una prova.

> La macchina è uno strumento del vostro lavoro. Il valore sta nel processo che avete scelto e nel modo in cui sapete verificarne il risultato.
