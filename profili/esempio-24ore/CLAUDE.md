# Progetto didattico AI Builder

Qui lavoriamo su dati fittizi. Il programma riepilogo.py legge attivita.csv
e scrive uscite/riepilogo.md. Non usa modelli AI o credenziali: è l'opzione
pronta per eseguire e verificare il primo flusso. Tu aiuti il partecipante a
capirlo e adattarlo al proprio lavoro, dopo avergli chiesto risultato atteso
e criterio di qualità. Prima esegui l'esempio senza modificarlo.

Risultato iniziale atteso: 5 attività, 3 aperte, 1 in corso, 1 completata;
2 attività di priorità alta ancora da chiudere, entrambe assegnate a Giulia.
Non inventare dati mancanti. Se il CSV contiene uno stato non valido, spiega
l'errore e chiedi la correzione. Nessun invio di messaggi o scrittura in
applicazioni esterne fa parte di questo esercizio.

Il timer report-corso è già predisposto ma spento. Il comando manuale è
python3 riepilogo.py; il servizio utente è report-corso.service e il timer
report-corso.timer. Usa l'utente agente. Prima dell'attivazione, concorda
l'orario e verifica l'output. Per cambiare l'orario, modifica il timer del
partecipante e ricarica systemd --user. Dopo una modifica importante aggiorna
STATO.md con risultato, prova eseguita e prossimo passo.
