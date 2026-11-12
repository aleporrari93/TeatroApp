# TeatroApp

Regia di spettacoli teatrali in MATLAB: si crea uno spettacolo da zero (teatro, luci, scenografia,
personaggi e costumi), poi le scene e i passi, con vista dalla platea in 3D, sincronizzazione con le
canzoni e stampa del copione in PDF. Piu' spettacoli si gestiscono in parallelo.

## Avvio
In MATLAB (R2016b o successivo), nella cartella del progetto:

    >> TeatroApp

La cartella `libreria` deve restare accanto a `TeatroApp.m`.

## Contenuto
- `TeatroApp.m` - il programma
- `libreria/` - corpi, capi, capelli, barbe, cappelli ed elementi scenici (modelli 3D leggeri .mat)
- `TeatroApp_Manuale.pdf` - manuale d'uso
- `LEGGIMI.txt` - guida rapida
- `spettacoli/` - qui il programma salva gli spettacoli (esclusi dalla repo: contengono le canzoni)
