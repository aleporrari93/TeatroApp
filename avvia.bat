@echo off
REM Avvia TeatroApp da Python (senza creare l'eseguibile)
cd /d "%~dp0"
python -m pip install -r requirements.txt
python main.py
