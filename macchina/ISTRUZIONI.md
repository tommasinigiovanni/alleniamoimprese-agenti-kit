# Le regole di questa macchina

Valgono per ogni sessione che gira qui, in qualsiasi cartella: il boss e
le sessioni dei progetti. La macchina è un server sempre acceso, preparato
dal kit del corso "Agenti che non dormono". Lavori come utente `agente`.

Questo file è del proprietario della macchina: lo può cambiare quando
vuole, anche chiedendolo a te.

## Con chi parli

Chi ti parla sta imparando e non è un tecnico.

- Prima di lanciare un comando, di' in una riga cosa fa.
- Quando qualcosa va storto, spiega cosa è successo e cosa si può fare.
  Non dare per scontato che sappia leggere un errore.
- Rispondi in italiano, con frasi corte.

## Da dove ti parla, e dove lancia i comandi

Quasi sempre ti parla dall'app sul telefono o dal browser, con Remote
Control. Da lì **non può lanciare comandi**: non ha un terminale, e i
comandi scritti con `!` davanti non funzionano. Non proporglieli.

Quando un comando lo deve lanciare lui (chiede una password nascosta,
oppure vuole `sudo`), ha un terminale solo in SSH, dal suo computer:
`ssh -p 2222 agente@INDIRIZZO-DELLA-MACCHINA`. Dagli il comando da
incollare lì, uno alla volta, completo di `cd` se serve una cartella, e
aspetta che ti dica che è fatto prima di andare avanti. Poi controlla tu
che sia andato.

Tutto il resto lo lanci tu.

## Cosa non passa dalla conversazione

Password, token e chiavi private non si scrivono qui, e tu non li chiedi.
Se serve un segreto, di' in quale file va scritto, dentro `~/segreti`
(un file per servizio, per esempio `~/segreti/telegram.txt`): lo scrive
lui da SSH, e il file lo legge solo il programma che lo usa. Se un
programma che costruisci ha bisogno di un segreto, fagli leggere quel
file: non copiarne il contenuto nel codice.

Una chiave pubblica invece si può incollare qui: è fatta per essere data.

## Quando serve l'amministratore

Tu non sei amministratore: non puoi cambiare il sistema. `sudo` a te non
funziona, perché chiede la password di agente e tu non la conosci. È
voluto.

Una cosa sola la puoi fare da solo: installare pacchetti di Ubuntu con
`installa NOME-PACCHETTO` (anche più nomi insieme). Passa senza password
e accetta solo nomi di pacchetti: usalo quando a un progetto serve un
programma di sistema (`caddy`, `ffmpeg`, `vim`), senza chiedere al
proprietario. Digli cosa hai installato e perché.

Per tutto il resto che vuole l'amministratore (un file in `/etc`, un
servizio di sistema, un utente, SSH) il proprietario può: da SSH scrive
`sudo` davanti al comando e la sua password. Dagli i comandi uno per uno,
con `sudo` davanti, e spiega cosa fanno. Non chiedergli la password e non
provare a passarla a `sudo` in nessun modo.

## Quello che deve restare acceso

Un programma che deve restare acceso quando lui chiude la finestra, e
ripartire da solo dopo un riavvio (una plancia, un bot, un servizio),
non si lancia a mano e non si lascia in una sessione di tmux: diventa
un servizio dell'utente. Lo fai tu, senza chiederglielo: un file
`~/.config/systemd/user/NOME.service`, poi
`systemctl --user enable --now NOME.service` (il linger è già acceso; se
il comando non trova il gestore dei servizi, prima
`export XDG_RUNTIME_DIR=/run/user/$(id -u)`). Poi controlla che sia
acceso con `systemctl --user status NOME.service` e diglielo.

## Farsi raggiungere da fuori

La macchina è remota: il proprietario non è seduto qui. Un indirizzo
come `http://127.0.0.1:PORTA` lui **non lo può aprire**. Non proporglielo,
e non proporre un tunnel SSH, a meno che non lo chieda lui.

Quando una pagina web che gira qui va aperta dal suo computer, la strada
è una: https con Caddy e un nome `sslip.io`.

1. Il programma resta in ascolto solo sulla macchina (`127.0.0.1:PORTA`).
2. Installa Caddy: `installa caddy`.
3. Trova l'IP pubblico (`curl -4 -fsS https://api.ipify.org`) e ricava il
   nome: l'IP con i trattini al posto dei punti, più `.sslip.io`. Per
   `188.245.7.28` è `188-245-7-28.sslip.io`.
4. La configurazione di Caddy sta in `/etc/caddy/Caddyfile`, che è
   dell'amministratore. Dagli da incollare in SSH, con il nome e la porta
   giusti:

   ```
   printf '%s\n' 'NOME.sslip.io {' '    reverse_proxy 127.0.0.1:PORTA' '}' | sudo tee /etc/caddy/Caddyfile
   sudo systemctl reload caddy
   ```

   Se nel file c'è già un altro sito, non sovrascriverlo: fagli aggiungere
   il blocco nuovo.
5. Digli di aprire nel firewall del pannello Hetzner le porte TCP 80 e
   443 in ingresso, verso tutti: il certificato lo rilascia un servizio
   esterno, che deve poter raggiungere la macchina. Il firewall è fuori
   dalla macchina: lo apre lui, tu non puoi.
6. Controlla tu che risponda: `curl -sI https://NOME.sslip.io`.

Una pagina aperta così la vede chiunque conosca l'indirizzo: deve avere
un suo accesso (password, meglio con un secondo fattore). Se non ce l'ha,
diglielo prima di aprire le porte.

Ogni porta aperta nel firewall è una scelta sua. Di' sempre quale porta
serve e perché, e ricordagli di richiuderla quando non serve più.

## Quello che deve durare sta nei file

Una conversazione finisce, un file resta. Quello che deve durare (una
decisione, un elenco, lo stato di un lavoro) si scrive in un file nella
cartella giusta.
