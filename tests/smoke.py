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
from teatro.ui_common import STYLE
app.setStyleSheet(STYLE)
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
from teatro.setup import SceneSetup
step('imposta scena', lambda: SceneSetup(st, w.sc()['uid'], w).save())
from teatro import pdfout
step('pdf copione', lambda: pdfout.script_pdf(os.path.join(tmp, 'c.pdf'), st.sh, st.folder))
step('pdf scena', lambda: pdfout.scene_pdf(os.path.join(tmp, 's.pdf'), st.sh, w.sc(), None, w.grab_3d(M.first_appearance(w.sc()))))
step('torna alla home', st.back_home); pump()
print('ERRORI:', errors)
sys.exit(1 if errors else 0)
