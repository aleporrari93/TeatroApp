@echo off
REM Crea TeatroApp.exe (Windows). Serve Python 3.10 o successivo installato (python.org, spunta "Add to PATH").
cd /d "%~dp0"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller
python -m PyInstaller --noconfirm --windowed --name TeatroApp --collect-all pyqtgraph --exclude-module pyqtgraph.examples --exclude-module pyqtgraph.jupyter --hidden-import OpenGL.platform.win32 main.py
xcopy /E /I /Y libreria dist\TeatroApp\libreria
copy /Y TeatroApp_Manuale.pdf dist\TeatroApp\
echo.
echo Fatto: il programma e' in dist\TeatroApp\TeatroApp.exe
pause
