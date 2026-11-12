# TeatroApp

Regia di spettacoli teatrali: si crea uno spettacolo da zero (teatro, luci, scenografia, personaggi e costumi),
poi le scene e i passi, con vista dalla platea in 3D, sincronizzazione con le canzoni e stampa del copione in PDF.
Piu' spettacoli si gestiscono in parallelo.

Scritto in Python (PySide6 + pyqtgraph), pensato per diventare un eseguibile Windows con PyInstaller.

## Avvio da sorgente
    pip install -r requirements.txt
    python main.py

## Creare l'eseguibile
Su Windows: doppio clic su `build_exe.bat`. Il programma viene creato in `dist\TeatroApp\TeatroApp.exe`
insieme alla cartella `libreria` e al manuale.

## Contenuto
- `main.py` e `teatro/` - il programma
- `libreria/` - corpi, capi, capelli, barbe, cappelli ed elementi scenici (modelli 3D leggeri .npz) e `catalogo.csv`
- `TeatroApp_Manuale.pdf` - manuale d'uso
- `build_exe.bat`, `avvia.bat`, `requirements.txt`
- `matlab/` - la prima versione del programma in MATLAB
