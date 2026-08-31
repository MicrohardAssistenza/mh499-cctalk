# MH499 ccTalk Tool

Webapp statica mobile-first per configurare e collaudare periferiche ccTalk
tramite la scheda Microhard **MH499** con interfaccia USB Silicon Labs CP210x.

L'interfaccia usa un tema chiaro ad alto contrasto, ottimizzato per l'impiego
all'aperto da smartphone.

## Funzioni

- collegamento alla MH499 tramite Web Serial o WebUSB;
- rilevamento e modifica dell'indirizzo ccTalk;
- programmazione del numero seriale DP10/14;
- verifica della comunicazione senza azionare il motore;
- test completo con lettura diagnostica ed erogazione di un pezzo;
- registro del traffico TX/RX in formato esadecimale.

## Utilizzo

1. Aprire la pagina con Chrome o Edge.
2. Collegare la MH499 al PC oppure a uno smartphone Android tramite USB OTG.
3. Premere **Collega MH499** e autorizzare il dispositivo Silicon Labs CP210x.
4. Eseguire prima **Rileva attuale** o **Verifica solo comunicazione**.

La comunicazione usa **9600 baud, 8 bit, nessuna parità, 2 stop bit (8N2)**.
La pagina deve essere servita tramite HTTPS; GitHub Pages soddisfa questo
requisito.

## Compatibilità

- PC: Chrome o Edge con driver CP210x installato;
- Android: Chrome e adattatore USB OTG, tramite WebUSB;
- iPhone/iPad: accesso USB diretto dal browser non disponibile.

## Sicurezza operativa

Il comando **Test completo** può erogare realmente un pezzo. La webapp richiede
una conferma esplicita prima dell'azionamento.

## Pubblicazione

Il workflow in `.github/workflows/static.yml` pubblica automaticamente il
contenuto del branch `main` su GitHub Pages a ogni aggiornamento.

Resta disponibile anche la versione Sites:
[mh499-cctalk.assistenza-durex.chatgpt.site](https://mh499-cctalk.assistenza-durex.chatgpt.site)
