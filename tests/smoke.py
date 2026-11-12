"""Prova automatica senza schermo (Qt 'offscreen'): apre le finestre principali ed esegue le azioni piu' comuni."""
import os, sys, tempfile, time, traceback
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from PySide6 import QtCore, QtWidgets
from teatro import paths
tmp = tempfile.mkdtemp()
real_lib = paths.lib_dir()
paths.app_dir = lambda: tmp
paths.lib_dir = lambda: real_lib
import teatro.library as L
L.lib_dir = paths.lib_dir
app = QtWidgets.QApplication(sys.argv)
from teatro.ui_common import STYLE, install_screen_guard
app.setStyleSheet(STYLE)
install_screen_guard(app)
errors = []

def step(name, f):
    try:
        f(); print('OK  ', name)
    except Exception:
        errors.append(name); print('FAIL', name); traceback.print_exc()

def pump(sec=0.3):
    t = time.time()
    while time.time() - t < sec:
        app.processEvents(); time.sleep(0.01)

from teatro.home import App, HomeWindow
from teatro import model as M
st = App(); home = HomeWindow(st); home.show(); pump()
QtWidgets.QMessageBox.information = staticmethod(lambda *a: None)
QtWidgets.QMessageBox.question = staticmethod(lambda *a: QtWidgets.QMessageBox.Yes)
step('crea esempio', lambda: home.demo()); pump()
sw = st.show_win
step('scheda teatro', lambda: sw.settings(0)); pump()
s = st.settings
step('teatro: quinte', lambda: (s.tabs.widget(0).ed['nq'].setText('4'), s.tabs.widget(0).read()))
step('luci: aggiungi', lambda: (s.tabs.widget(1).lib.setCurrentRow(5), s.tabs.widget(1).add()))
step('scenografia: aggiungi', lambda: (s.tabs.widget(2).lc.setCurrentRow(2), s.tabs.widget(2).add_lib()))
step('personaggi: costume', lambda: (s.tabs.setCurrentIndex(3), s.tabs.widget(3).lp.setCurrentRow(0), s.tabs.widget(3).pIt[7].setCurrentIndex(2)))
def fits(win):
    av = app.primaryScreen().availableGeometry(); g = win.geometry()
    print('     ', type(win).__name__, g.width(), 'x', g.height(), 'schermo', av.width(), 'x', av.height())
    assert g.width() <= av.width() and g.height() <= av.height(), 'finestra piu\' grande dello schermo'
    win.resize(5000, 5000); app.processEvents(); g = win.geometry()
    assert g.width() <= av.width() and g.height() <= av.height(), 'si puo\' allargare oltre lo schermo'
    assert g.left() >= av.left() and g.top() >= av.top(), 'finestra fuori dallo schermo'
step('impostazioni nello schermo', lambda: fits(s))
pump(); step('chiudi impostazioni', s.close); pump()
step('apri scena', lambda: (sw.lb.setCurrentRow(1), sw.open_scene())); pump()
w = st.scene_win
step('montaggio', lambda: w.montage()); pump(3)
step('vista 3D', lambda: w.toggle_view()); pump(1)
step('vista alto', lambda: w.toggle_view())
from teatro.scene import StepList
from teatro.stepedit import StepEditor
def edit():
    sl = StepList(w); ed = StepEditor(w, len(w.sc()['steps']), True, sl)
    ed.pC.setCurrentIndex(0); ed.m_down(1, 2, 1); ed.add_action(); ed.save()
step('nuovo passo', edit)
def big_windows():
    fits(w); fits(st.show_win)
    ed = StepEditor(w, 0, False, StepList(w)); ed.show(); pump(0.3); fits(ed); ed.reject()
step('scena e passo nello schermo', big_windows)
from teatro.setup import SceneSetup
def dump(lay, ind):
    for k in range(lay.count()):
        it = lay.itemAt(k); m = it.minimumSize(); w = it.widget(); l = it.layout()
        nm = type(w).__name__ if w else (type(l).__name__ if l else 'spazio')
        txt = ''
        if w is not None and hasattr(w, 'text') and callable(w.text):
            txt = str(w.text())[:40]
        if m.width() >= 120:
            print(' ' * ind, nm, m.width(), 'x', m.height(), repr(txt))
        if l is not None:
            dump(l, ind + 3)
        elif w is not None and w.layout() is not None and m.width() >= 120:
            dump(w.layout(), ind + 3)
def need(win, name):
    """spazio minimo richiesto dal contenuto: deve stare in uno schermo da portatile (1280 x 680) senza scorrere"""
    sa = win.findChild(QtWidgets.QScrollArea); m = sa.widget().minimumSizeHint()
    print('      contenuto minimo', name, m.width(), 'x', m.height())
    if m.width() > 1260 or m.height() > 640:
        big = []
        tw = sa.widget().findChild(QtWidgets.QTabWidget)
        if tw is not None:
            for i in range(tw.count()):
                h = tw.widget(i).minimumSizeHint(); print('        scheda', i, type(tw.widget(i)).__name__, h.width(), 'x', h.height())
                if h.width() > 900:
                    dump(tw.widget(i).layout(), 10)
        for c in sa.widget().findChildren(QtWidgets.QWidget):
            h = c.minimumSizeHint(); mw = max(h.width(), c.minimumWidth())
            txt = c.text() if hasattr(c, 'text') and callable(c.text) else (c.currentText() if hasattr(c, 'currentText') else '')
            if mw > 300 or h.height() > 400:
                big.append((mw, h.height(), type(c).__name__, str(txt)[:60]))
        for x in sorted(big, reverse=True)[:25]:
            print('        troppo grande:', x)
    assert m.width() <= 1260 and m.height() <= 640, 'servono le barre di scorrimento in ' + name
def setup_fit():
    ss = SceneSetup(st, w.sc()['uid'], w); ss.show(); pump(0.3); need(ss, 'Imposta scena'); ss.reject()
    ed = StepEditor(w, 0, False, StepList(w)); ed.show(); pump(0.3); need(ed, 'Passo'); ed.reject()
    need(st.scene_win, 'Scena'); need(st.show_win, 'Spettacolo')
    st.show_win.settings(0); pump(0.3)
    for i in range(4):
        st.settings.tabs.setCurrentIndex(i); pump(0.2); need(st.settings, 'Impostazioni scheda %d' % i)
    st.settings.close(); pump()
    seen = []
    orig = QtWidgets.QDialog.exec
    QtWidgets.QDialog.exec = lambda self: (self.show(), pump(0.3), seen.append(self), self.reject())
    try:
        st.scene_win.costumes()
    finally:
        QtWidgets.QDialog.exec = orig
    need(seen[0], 'Costumi della scena')
step('finestre leggibili senza scorrere', setup_fit)
step('imposta scena', lambda: SceneSetup(st, w.sc()['uid'], w).save())
from teatro import pdfout
step('pdf copione', lambda: pdfout.script_pdf(os.path.join(tmp, 'c.pdf'), st.sh, st.folder))
step('pdf scena', lambda: pdfout.scene_pdf(os.path.join(tmp, 's.pdf'), st.sh, w.sc(), None, w.grab_3d(M.first_appearance(w.sc()))))
step('torna alla home', st.back_home); pump()
print('ERRORI:', errors)
sys.exit(1 if errors else 0)
