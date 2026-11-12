"""Percorsi del programma: funzionano sia da sorgente sia come .exe (PyInstaller)."""
import os
import sys


def app_dir():
    """Cartella in cui si trova il programma (accanto all'.exe quando e' compilato)."""
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lib_dir():
    """Cartella della libreria: accanto al programma, oppure dentro l'eseguibile."""
    d = os.path.join(app_dir(), 'libreria')
    if os.path.isdir(d):
        return d
    base = getattr(sys, '_MEIPASS', None)
    if base and os.path.isdir(os.path.join(base, 'libreria')):
        return os.path.join(base, 'libreria')
    return d


def shows_dir():
    d = os.path.join(app_dir(), 'spettacoli')
    os.makedirs(d, exist_ok=True)
    return d
