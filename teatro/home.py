"""Finestra iniziale (elenco degli spettacoli) e finestra dello spettacolo (elenco delle scene)."""
import json
import os
import shutil
import tempfile
import zipfile

from PySide6 import QtCore, QtWidgets

from . import model as M
from . import pdfout
from .demo import make_demo
from .paths import shows_dir
from .ui_common import ask_text, button, confirm, error, info, label, open_folder


class App:
    """stato condiviso: lo spettacolo aperto e le sue finestre"""
    def __init__(self):
        self.sh = None; self.folder = ''; self.home = None; self.show_win = None; self.scene_win = None; self.settings = None

    def save(self):
        if self.sh and self.folder:
            try:
                M.save_show(self.sh, self.folder)
            except OSError as e:
                error(None, 'Salvataggio non riuscito: %s' % e)

    def open_show(self, folder):
        try:
            sh = M.load_show(folder)
        except Exception as e:
            error(self.home, 'Impossibile aprire lo spettacolo: %s' % e); return
        self.close_show_windows()
        for sub in ('audio', 'modelli', 'cue', 'fondale'):
            os.makedirs(os.path.join(folder, sub), exist_ok=True)
        self.sh = sh; self.folder = folder
        self.show_win = ShowWindow(self); self.show_win.show()
        if self.home:
            self.home.hide()

    def close_show_windows(self):
        for w in (self.scene_win, self.settings, self.show_win):
            if w is not None:
                try:
                    w.blockSignals(True); w.close_quiet()
                except Exception:
                    pass
        self.scene_win = self.settings = self.show_win = None

    def back_home(self):
        self.save(); self.close_show_windows(); self.sh = None; self.folder = ''
        self.home.refresh(); self.home.show(); self.home.raise_()


class HomeWindow(QtWidgets.QWidget):
    def __init__(self, app):
        super().__init__(); self.app = app; app.home = self; self.list = []
        self.setWindowTitle('Teatro  -  i miei spettacoli'); self.resize(980, 640)
        lay = QtWidgets.QVBoxLayout(self)
        lay.addWidget(label('I MIEI SPETTACOLI', 'title'))
        lay.addWidget(label('Doppio clic su uno spettacolo per aprirlo. Ogni spettacolo si salva da solo nella sua cartella.', 'dim'))
        h = QtWidgets.QHBoxLayout(); lay.addLayout(h, 1)
        self.lb = QtWidgets.QListWidget(); self.lb.itemDoubleClicked.connect(lambda *_: self.open_sel()); h.addWidget(self.lb, 3)
        v = QtWidgets.QVBoxLayout(); h.addLayout(v, 1)
        for t, cb, acc in (('+ Nuovo spettacolo', self.new_show, True), ('Apri', self.open_sel, False), ('Duplica', self.dup, False),
                           ('Rinomina', self.rename, False), ('Elimina', self.delete, False), ('Esporta in .zip', self.export, False),
                           ('Importa da .zip', self.import_zip, False), ('Apri la cartella', lambda: open_folder(shows_dir()), False),
                           ('Crea spettacolo di esempio', self.demo, False)):
            v.addWidget(button(t, cb, acc))
        v.addStretch(1)
        self.st = label('', 'dim', True); lay.addWidget(self.st)
        self.refresh()

    def refresh(self):
        self.list = []
        for d in os.listdir(shows_dir()):
            f = os.path.join(shows_dir(), d, 'spettacolo.json')
            if not os.path.exists(f):
                continue
            try:
                j = json.load(open(f, encoding='utf-8'))
                self.list.append(dict(folder=os.path.join(shows_dir(), d), title=j.get('title', d), date=j.get('modified', ''), n=len(j.get('scenes', []))))
            except Exception:
                self.list.append(dict(folder=os.path.join(shows_dir(), d), title=d, date='', n=0))
        self.list.sort(key=lambda x: x['date'], reverse=True)
        self.lb.clear()
        for x in self.list:
            self.lb.addItem('%s      (%d scene, modificato %s)' % (x['title'], x['n'], x['date']))
        if not self.list:
            self.lb.addItem('(nessuno spettacolo: premi "+ Nuovo spettacolo" oppure "Crea spettacolo di esempio")')

    def sel(self):
        r = self.lb.currentRow()
        return self.list[r] if 0 <= r < len(self.list) else None

    def new_show(self):
        a = ask_text(self, 'Nuovo spettacolo', ['Titolo dello spettacolo'])
        if not a or not a[0]:
            return
        folder = M.make_show_folder(shows_dir(), a[0])
        M.save_show(M.default_show(a[0]), folder)
        self.refresh(); self.app.open_show(folder)
        from .settings import SettingsDialog
        self.app.settings = SettingsDialog(self.app, 0, wizard=True); self.app.settings.show()

    def open_sel(self):
        s = self.sel()
        if s:
            self.app.open_show(s['folder'])

    def dup(self):
        s = self.sel()
        if not s:
            return
        t = s['title'] + ' (copia)'
        dst = M.make_show_folder(shows_dir(), t); shutil.rmtree(dst); shutil.copytree(s['folder'], dst)
        sh = M.load_show(dst); sh['title'] = t; M.save_show(sh, dst)
        self.refresh(); self.st.setText('Creata la copia: ' + t)

    def rename(self):
        s = self.sel()
        if not s:
            return
        a = ask_text(self, 'Rinomina', ['Nuovo titolo'], [s['title']])
        if not a or not a[0]:
            return
        sh = M.load_show(s['folder']); sh['title'] = a[0]; M.save_show(sh, s['folder']); self.refresh()

    def delete(self):
        s = self.sel()
        if s and confirm(self, 'Eliminare definitivamente "%s" con tutti i suoi file?' % s['title'], 'Elimina'):
            shutil.rmtree(s['folder'], ignore_errors=True); self.refresh()

    def export(self):
        s = self.sel()
        if not s:
            return
        fn, _ = QtWidgets.QFileDialog.getSaveFileName(self, 'Esporta lo spettacolo', os.path.basename(s['folder']) + '.zip', 'Archivio zip (*.zip)')
        if not fn:
            return
        base = os.path.dirname(s['folder'])
        with zipfile.ZipFile(fn, 'w', zipfile.ZIP_DEFLATED) as z:
            for root, _, files in os.walk(s['folder']):
                for f in files:
                    p = os.path.join(root, f); z.write(p, os.path.relpath(p, base))
        self.st.setText('Esportato in ' + fn)

    def import_zip(self):
        fn, _ = QtWidgets.QFileDialog.getOpenFileName(self, 'Importa uno spettacolo', '', 'Archivio zip (*.zip)')
        if not fn:
            return
        tmp = tempfile.mkdtemp()
        try:
            zipfile.ZipFile(fn).extractall(tmp)
            src = None
            for root, _, files in os.walk(tmp):
                if 'spettacolo.json' in files:
                    src = root; break
            if not src:
                raise ValueError('nel file .zip non c\'e\' nessuno spettacolo.json')
            t = M.load_show(src)['title']
            dst = M.make_show_folder(shows_dir(), t); shutil.rmtree(dst); shutil.copytree(src, dst)
            self.st.setText('Importato: ' + t)
        except Exception as e:
            error(self, 'Importazione non riuscita: %s' % e)
        shutil.rmtree(tmp, ignore_errors=True); self.refresh()

    def demo(self):
        f = make_demo(shows_dir()); self.refresh(); self.app.open_show(f)
        if self.app.show_win:
            self.app.show_win.msg('Spettacolo di esempio creato: apri una scena, prova "Montaggio" e "Vista da pubblico". '
                                  'Metti le canzoni "00 ....mp3" e "01 ....mp3" nella cartella audio.')


class ShowWindow(QtWidgets.QWidget):
    def __init__(self, app):
        super().__init__(); self.app = app; self._quiet = False
        self.setWindowTitle('Spettacolo  -  ' + app.sh['title']); self.resize(1100, 720)
        lay = QtWidgets.QVBoxLayout(self)
        self.title = label(app.sh['title'], 'title'); lay.addWidget(self.title)
        self.info = label('', 'dim'); lay.addWidget(self.info)
        top = QtWidgets.QHBoxLayout(); lay.addLayout(top)
        for t, tab in (('Teatro', 0), ('Luci', 1), ('Scenografia', 2), ('Personaggi e costumi', 3)):
            top.addWidget(button(t, lambda tab=tab: self.settings(tab)))
        top.addWidget(button('Cartella canzoni', lambda: open_folder(os.path.join(app.folder, 'audio'))))
        lay.addWidget(label('SCENE  (doppio clic per aprire)', 'head'))
        h = QtWidgets.QHBoxLayout(); lay.addLayout(h, 1)
        self.lb = QtWidgets.QListWidget(); self.lb.setStyleSheet('font-family: Consolas, "Courier New", monospace;')
        self.lb.itemDoubleClicked.connect(lambda *_: self.open_scene()); h.addWidget(self.lb, 3)
        v = QtWidgets.QVBoxLayout(); h.addLayout(v, 1)
        v.addWidget(button('+ Nuova scena', self.new_scene, True))
        v.addWidget(button('▶  Apri la scena', self.open_scene, True))
        v.addWidget(button('Titolo, numero, atto', self.edit_scene))
        v.addWidget(button('Imposta scena', self.setup))
        v.addWidget(button('Duplica scena', self.dup_scene))
        v.addWidget(button('Elimina scena', self.del_scene))
        v.addSpacing(12)
        v.addWidget(button('⎙  Stampa intero copione', self.print_script, True, 'PDF con una pagina per scena: titolo, atto, numero e passi'))
        v.addWidget(button('Salva', self.do_save))
        v.addWidget(button('◀  I miei spettacoli', app.back_home))
        v.addStretch(1)
        self.st = label('', 'dim', True); lay.addWidget(self.st)
        self.refresh()

    def close_quiet(self):
        self._quiet = True; self.close()

    def closeEvent(self, ev):
        if not self._quiet:
            QtCore.QTimer.singleShot(0, self.app.back_home)
        ev.accept()

    def msg(self, s):
        self.st.setText(s)

    def refresh(self, select_uid=None):
        sh = self.app.sh; T = sh['theater']
        self.setWindowTitle('Spettacolo  -  ' + sh['title']); self.title.setText(sh['title'])
        self.info.setText('Palco %g x %g m (+ %g m di proscenio), altezza %g m, %d quinte per lato   |   %d personaggi   |   %d elementi scenici   |   %d luci'
                          % (T['W'], T['D'], T['P'], T['H'], T['nq'], len(sh['chars']), len(sh['elements']), len(sh['lights'])))
        M.sort_scenes(sh)
        r = self.lb.currentRow(); self.lb.clear()
        for sc in sh['scenes']:
            mk = '♪' if M.find_music(self.app.folder, sc['num']) else '(manca %02d.mp3)' % sc['num']
            self.lb.addItem('Atto %-4s Scena %2d   %-36s %3d passi  %s' % (M.roman(sc['act']), sc['num'], sc['title'][:36], len(sc['steps']), mk))
        if not sh['scenes']:
            self.lb.addItem('(nessuna scena: premi "+ Nuova scena")')
        if select_uid is not None:
            r = next((i for i, s in enumerate(sh['scenes']) if s['uid'] == select_uid), r)
        self.lb.setCurrentRow(max(0, min(r, self.lb.count() - 1)))

    def sel(self):
        r = self.lb.currentRow()
        return r if 0 <= r < len(self.app.sh['scenes']) else -1

    def do_save(self):
        self.app.save(); self.msg('Salvato  (%s)' % self.app.sh['modified'])

    def settings(self, tab):
        from .settings import SettingsDialog
        if self.app.settings is not None:
            self.app.settings.close_quiet()
        self.app.settings = SettingsDialog(self.app, tab, wizard=False); self.app.settings.show()

    def new_scene(self):
        sh = self.app.sh; act, num = 1, 1
        if sh['scenes']:
            act = sh['scenes'][-1]['act']; num = sh['scenes'][-1]['num'] + 1
        a = ask_text(self, 'Nuova scena', ['Atto (1, 2, ...)', 'Numero della scena (0 = intro; corrisponde alla canzone 00, 01, ...)',
                                          'Titolo della scena', 'Situazione iniziale (facoltativa)'], [act, num, '', ''])
        if not a:
            return
        try:
            act = int(float(a[0])); num = int(float(a[1]))
        except ValueError:
            error(self, 'Atto e numero devono essere numeri.'); return
        sc = M.new_scene(M.new_uid(sh), act, num, a[2], a[3])
        sh['scenes'].append(sc); self.app.save(); self.refresh(sc['uid'])
        self.msg("Scena creata. Ora scegli chi c'e' in scena, i costumi e le posizioni iniziali.")
        self.setup()

    def edit_scene(self):
        k = self.sel()
        if k < 0:
            return
        sc = self.app.sh['scenes'][k]
        a = ask_text(self, 'Modifica scena', ['Atto', 'Numero della scena', 'Titolo', 'Situazione iniziale'],
                     [sc['act'], sc['num'], sc['title'], sc['start']])
        if not a:
            return
        try:
            sc['act'] = int(float(a[0])); sc['num'] = int(float(a[1]))
        except ValueError:
            pass
        sc['title'] = a[2] or sc['title']; sc['start'] = a[3]
        self.app.save(); self.refresh(sc['uid'])
        if self.app.scene_win:
            self.app.scene_win.go_uid(sc['uid'])

    def open_scene(self):
        k = self.sel()
        if k < 0:
            return
        from .scene import SceneWindow
        if self.app.scene_win is None:
            self.app.scene_win = SceneWindow(self.app)
        self.app.scene_win.show(); self.app.scene_win.raise_(); self.app.scene_win.go(k)

    def setup(self):
        k = self.sel()
        if k < 0:
            return
        from .setup import SceneSetup
        SceneSetup(self.app, self.app.sh['scenes'][k]['uid'], self).exec()

    def dup_scene(self):
        k = self.sel()
        if k < 0:
            return
        import copy
        sc = copy.deepcopy(self.app.sh['scenes'][k]); sc['uid'] = M.new_uid(self.app.sh); sc['title'] += ' (copia)'
        self.app.sh['scenes'].append(sc); self.app.save(); self.refresh(sc['uid'])

    def del_scene(self):
        k = self.sel()
        if k < 0:
            return
        sc = self.app.sh['scenes'][k]
        if not confirm(self, 'Eliminare la scena "%s" con tutti i suoi passi?' % sc['title'], 'Elimina scena'):
            return
        if self.app.scene_win:
            self.app.scene_win.close_quiet(); self.app.scene_win = None
        del self.app.sh['scenes'][k]; self.app.save(); self.refresh()

    def print_script(self):
        sh = self.app.sh
        if not sh['scenes']:
            info(self, 'Lo spettacolo non ha ancora scene.'); return
        fn, _ = QtWidgets.QFileDialog.getSaveFileName(self, "Salva l'intero copione in PDF",
                                                      os.path.join(self.app.folder, M.safe_name(sh['title']) + ' - copione.pdf'), 'PDF (*.pdf)')
        if not fn:
            return
        try:
            pdfout.script_pdf(fn, sh, self.app.folder); self.msg('Copione salvato: ' + fn); info(self, 'Copione salvato in:\n' + fn)
        except Exception as e:
            error(self, 'Errore nella creazione del copione: %s' % e)
