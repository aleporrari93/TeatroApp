"""Impostazioni dello spettacolo: teatro, luci, scenografia, personaggi e costumi."""
import copy
import os
import shutil

from PySide6 import QtCore, QtWidgets

from . import importers as IM
from . import library as L
from . import model as M
from .planview import PlanView
from .ui_common import ColorButton, ask_text, button, confirm, error, fit_window, info, label, num, window_layout
from .view3d import Preview3D


def import_dialog(parent, folder):
    """scegli e importa un modello 3D; ritorna (file, misure, nome) oppure (None, None, None)"""
    fn, _ = QtWidgets.QFileDialog.getOpenFileName(parent, 'Scegli il modello 3D', '', 'Modelli 3D (*.glb *.obj *.npz)')
    if not fn:
        return None, None, None
    yup = None
    if fn.lower().endswith('.obj'):
        r = QtWidgets.QMessageBox.question(parent, 'Importa', "Nel file, l'asse verso l'alto e' Y (Blender, la maggior parte)?\n"
                                           "Rispondi No se e' Z.", QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No)
        yup = r == QtWidgets.QMessageBox.Yes
    QtWidgets.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
    try:
        f, bb, nf = IM.import_model(fn, folder, yup)
    except Exception as e:
        QtWidgets.QApplication.restoreOverrideCursor(); error(parent, 'Importazione non riuscita: %s' % e); return None, None, None
    QtWidgets.QApplication.restoreOverrideCursor()
    info(parent, 'Modello importato: %d facce, %.2f x %.2f x %.2f m.' % (nf, bb[0], bb[1], bb[2]), 'Importa')
    return f, bb, os.path.splitext(os.path.basename(fn))[0]


class SettingsDialog(QtWidgets.QWidget):
    def __init__(self, app, tab=0, wizard=False):
        super().__init__(); self.app = app; self._quiet = False
        self.setWindowTitle('Impostazioni  -  ' + app.sh['title']); fit_window(self, 1400, 860)
        lay = window_layout(self)
        self.tabs = QtWidgets.QTabWidget(); lay.addWidget(self.tabs, 1)
        self.tabs.addTab(TheaterTab(app), '  1. Teatro  ')
        self.tabs.addTab(LightsTab(app), '  2. Luci  ')
        self.tabs.addTab(ElementsTab(app), '  3. Scenografia  ')
        self.tabs.addTab(CharsTab(app), '  4. Personaggi e costumi  ')
        self.tabs.setCurrentIndex(tab)
        b = QtWidgets.QHBoxLayout(); lay.addLayout(b)
        if wizard:
            b.addWidget(label('Nuovo spettacolo: compila le 4 schede in ordine (puoi sempre tornarci dalla finestra dello spettacolo).', 'hint'))
            b.addStretch(1)
            b.addWidget(button('◀ Indietro', lambda: self.tabs.setCurrentIndex(max(0, self.tabs.currentIndex() - 1))))
            b.addWidget(button('Avanti ▶', self.next_tab, True))
        else:
            b.addStretch(1)
        b.addWidget(button('Salva e chiudi', self.close, True))

    def next_tab(self):
        if self.tabs.currentIndex() >= 3:
            self.close()
        else:
            self.tabs.setCurrentIndex(self.tabs.currentIndex() + 1)

    def close_quiet(self):
        self._quiet = True; self.close()

    def closeEvent(self, ev):
        L.clear_cache(); self.app.save()
        if not self._quiet:
            if self.app.show_win:
                self.app.show_win.refresh()
            if self.app.scene_win:
                self.app.scene_win.reload()
        if self.app.settings is self:
            self.app.settings = None
        ev.accept()


# ------------------------------------------------------------------ teatro
class TheaterTab(QtWidgets.QWidget):
    PRE = [('Personalizzato', None), ('Piccolo (8 x 7 m, h 5 m, 2 quinte)', [8, 7, 5, 2, 1]),
           ('Medio (10 x 9,2 m, h 7 m, 3 quinte)', [10, 9.2, 7, 3, 1.2]), ('Grande (14 x 11,5 m, h 9 m, 4 quinte)', [14, 11.5, 9, 4, 1.5]),
           ('Molto grande (18 x 16 m, h 12 m, 5 quinte)', [18, 16, 12, 5, 2])]
    FIELDS = [('W', 'Larghezza del palco (m)'), ('Dtot', "Profondita' totale, proscenio compreso (m)"), ('H', 'Altezza (graticcio) (m)'),
              ('nq', 'Numero di quinte per lato'), ('P', "Profondita' del proscenio (m)")]

    def __init__(self, app):
        super().__init__(); self.app = app
        h = QtWidgets.QHBoxLayout(self); left = QtWidgets.QVBoxLayout(); h.addLayout(left, 2)
        left.addWidget(label('Il teatro', 'title'))
        f = QtWidgets.QFormLayout(); left.addLayout(f)
        self.pre = QtWidgets.QComboBox(); self.pre.addItems([p[0] for p in self.PRE]); self.pre.currentIndexChanged.connect(self.preset)
        f.addRow('Modello di partenza', self.pre)
        self.ed = {}
        for k, t in self.FIELDS:
            e = QtWidgets.QLineEdit(str(app.sh['theater'][k])); e.editingFinished.connect(self.read); f.addRow(t, e); self.ed[k] = e
        self.inf = label('', 'hint', True); left.addWidget(self.inf)
        f2 = QtWidgets.QFormLayout(); left.addLayout(f2)
        self.back = QtWidgets.QComboBox(); self.back.addItems(M.BACKS); self.back.setCurrentText(app.sh['theater']['back'])
        self.back.currentIndexChanged.connect(self.pick_back); f2.addRow('Fondale', self.back)
        self.bfile = button('Scegli il file...', lambda: self.choose_back(True)); f2.addRow('', self.bfile)
        self.tfile = label('', 'dim'); f2.addRow('', self.tfile)
        left.addWidget(label("Misure in metri. Le quinte si dividono da sole la profondita' del palco (proscenio escluso): scrivi solo quante sono. "
                             "Immagine: jpg/png, viene stesa su tutta la larghezza. Modello 3D: .glb/.obj, adattato alla larghezza.", 'dim', True))
        left.addStretch(1)
        self.plan = PlanView(); self.plan.show_size = True; self.plan.title = 'Pianta (pubblico in basso)'; h.addWidget(self.plan, 3)
        self.plan.set_context(app.sh, app.folder); self.draw()

    def preset(self):
        v = self.PRE[self.pre.currentIndex()][1]
        if v:
            for (k, _), x in zip(self.FIELDS, v):
                self.ed[k].setText(str(x))
            self.read()

    def read(self):
        T = self.app.sh['theater']
        for k, _ in self.FIELDS:
            x = num(self.ed[k].text(), None)
            if x is not None and x >= 0:
                T[k] = x
        M.fix_theater(T)
        for k, _ in self.FIELDS:
            self.ed[k].setText(('%g' % T[k]))
        self.draw()

    def pick_back(self):
        T = self.app.sh['theater']; nb = self.back.currentText()
        need = (nb == 'Immagine (foto o disegno)' and not T['backImg']) or (nb == 'Modello 3D' and not T['backModel'])
        T['back'] = nb
        if need and not self.choose_back(False):
            T['back'] = 'Nero'; self.back.blockSignals(True); self.back.setCurrentIndex(0); self.back.blockSignals(False)
        self.draw()

    def choose_back(self, redraw):
        T = self.app.sh['theater']; folder = self.app.folder
        if T['back'] == 'Immagine (foto o disegno)':
            fn, _ = QtWidgets.QFileDialog.getOpenFileName(self, 'Immagine del fondale', '', 'Immagini (*.jpg *.jpeg *.png *.bmp)')
            if not fn:
                return False
            d = os.path.join(folder, 'fondale'); os.makedirs(d, exist_ok=True)
            shutil.copy(fn, os.path.join(d, os.path.basename(fn))); T['backImg'] = os.path.basename(fn)
        elif T['back'] == 'Modello 3D':
            f, _, _ = import_dialog(self, folder)
            if not f:
                return False
            T['backModel'] = f
        else:
            info(self, 'Scegli prima "Immagine" o "Modello 3D" come fondale.'); return False
        if redraw:
            self.draw()
        return True

    def draw(self):
        T = self.app.sh['theater']
        self.inf.setText("Calcolato: palco %.2f m di profondita' + %.2f m di proscenio.\n%d quinte per lato, una ogni %.2f m, larghe %.2f m; "
                         "spazio dietro le quinte %.2f m." % (T['D'], T['P'], T['nq'], M.quinte_step(T), M.quinte_width(T), T['wing']))
        self.bfile.setEnabled(T['back'] in ('Immagine (foto o disegno)', 'Modello 3D'))
        self.tfile.setText({'Immagine (foto o disegno)': 'Immagine: ' + T['backImg'], 'Modello 3D': 'Modello: ' + T['backModel']}.get(T['back'], ''))
        self.plan.update()


# ------------------------------------------------------------------ luci
class LightsTab(QtWidgets.QWidget):
    def __init__(self, app):
        super().__init__(); self.app = app; self._fill = False
        h = QtWidgets.QHBoxLayout(self); left = QtWidgets.QVBoxLayout(); h.addLayout(left, 2)
        left.addWidget(label('Luci disponibili', 'title')); left.addWidget(label('Libreria (doppio clic o "Aggiungi")', 'dim'))
        self.lib = QtWidgets.QListWidget()
        for t, n, z, c, q in M.LIGHT_LIBRARY:
            self.lib.addItem('%s  -  %s' % (t, n))
        self.lib.itemDoubleClicked.connect(lambda *_: self.add()); left.addWidget(self.lib, 1)
        left.addWidget(button('Aggiungi ▶', self.add, True))
        right = QtWidgets.QVBoxLayout(); h.addLayout(right, 3)
        right.addWidget(label("Luci di questo spettacolo (modifica nome, quantita', colore e zona)", 'dim'))
        self.tb = QtWidgets.QTableWidget(0, 5); self.tb.setHorizontalHeaderLabels(['Nome', 'Tipo', "Q.ta'", 'Colore', 'Zona'])
        self.tb.horizontalHeader().setSectionResizeMode(QtWidgets.QHeaderView.Stretch); self.tb.verticalHeader().setVisible(False)
        self.tb.itemChanged.connect(self.name_changed); right.addWidget(self.tb, 1)
        b = QtWidgets.QHBoxLayout(); right.addLayout(b)
        b.addWidget(button('Rimuovi', self.remove, tip='Rimuove la luce selezionata')); b.addWidget(button('Colore...', self.custom, tip='Colore personalizzato')); b.addStretch(1)
        right.addWidget(label('"Segue un personaggio" = occhio di bue / testa mobile: nei passi puo\' seguire un personaggio. '
                              'Le altre zone sono luci generali: nei passi scegli quali restano accese.', 'dim', True))
        self.fill()

    def fill(self):
        self._fill = True; Ls = self.app.sh['lights']; self.tb.setRowCount(len(Ls))
        for r, Lt in enumerate(Ls):
            self.tb.setItem(r, 0, QtWidgets.QTableWidgetItem(Lt['name']))
            it = QtWidgets.QTableWidgetItem(Lt['type']); it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable); self.tb.setItem(r, 1, it)
            sp = QtWidgets.QSpinBox(); sp.setRange(0, 999); sp.setValue(int(Lt['qty']))
            sp.valueChanged.connect(lambda v, r=r: self.set_field(r, 'qty', v)); self.tb.setCellWidget(r, 2, sp)
            cb = QtWidgets.QComboBox(); cb.addItems(M.COLN); cb.setCurrentText(Lt['cname'])
            cb.currentTextChanged.connect(lambda t, r=r: self.set_colour(r, t)); self.tb.setCellWidget(r, 3, cb)
            zb = QtWidgets.QComboBox(); zb.addItems(M.ZONES); zb.setCurrentText(Lt['zone'])
            zb.currentTextChanged.connect(lambda t, r=r: self.set_field(r, 'zone', t)); self.tb.setCellWidget(r, 4, zb)
        self._fill = False

    def add(self):
        r = self.lib.currentRow()
        if r < 0:
            return
        t, n, z, c, q = M.LIGHT_LIBRARY[r]; names = [l['name'] for l in self.app.sh['lights']]; nm = t; k = 2
        while nm in names:
            nm = '%s %d' % (t, k); k += 1
        self.app.sh['lights'].append(M.new_light(nm, t, q, c, M.colour_of(c), z)); self.fill()

    def name_changed(self, it):
        if self._fill or it.column() != 0:
            return
        r = it.row(); nm = it.text().strip(); Ls = self.app.sh['lights']
        if nm and all(l['name'] != nm for i, l in enumerate(Ls) if i != r):
            Ls[r]['name'] = nm
        else:
            self.fill()

    def set_field(self, r, k, v):
        if not self._fill:
            self.app.sh['lights'][r][k] = v

    def set_colour(self, r, t):
        if self._fill:
            return
        Lt = self.app.sh['lights'][r]
        if t == 'Personalizzato':
            from .ui_common import qcol
            c = QtWidgets.QColorDialog.getColor(qcol(Lt['rgb']), self, 'Colore della luce')
            if c.isValid():
                Lt['rgb'] = [c.redF(), c.greenF(), c.blueF()]
        else:
            Lt['rgb'] = M.colour_of(t)
        Lt['cname'] = t

    def remove(self):
        r = self.tb.currentRow()
        if 0 <= r < len(self.app.sh['lights']):
            del self.app.sh['lights'][r]; self.fill()

    def custom(self):
        r = self.tb.currentRow()
        if 0 <= r < len(self.app.sh['lights']):
            self.tb.cellWidget(r, 3).setCurrentText('Personalizzato'); self.set_colour(r, 'Personalizzato')


# ------------------------------------------------------------------ scenografia
class ElementsTab(QtWidgets.QWidget):
    def __init__(self, app):
        super().__init__(); self.app = app; self._fill = False
        self.cat = [c for c in L.read_catalog() if c['cat'] == 'Scenografia']
        h = QtWidgets.QHBoxLayout(self)
        c1 = QtWidgets.QVBoxLayout(); h.addLayout(c1, 2)
        c1.addWidget(label('Scenografia', 'title')); c1.addWidget(label('Elementi predefiniti (doppio clic per aggiungere)', 'dim'))
        self.lc = QtWidgets.QListWidget(); self.lc.addItems([c['name'] for c in self.cat]); self.lc.itemDoubleClicked.connect(lambda *_: self.add_lib())
        c1.addWidget(self.lc, 1); c1.addWidget(button('Aggiungi ▶', self.add_lib, True))
        c1.addWidget(button('Importa modello 3D...', self.add_import, tip='File .glb, .obj o .npz'))
        c2 = QtWidgets.QVBoxLayout(); h.addLayout(c2, 2)
        c2.addWidget(label('Elementi di questo spettacolo', 'dim'))
        self.le = QtWidgets.QListWidget(); self.le.currentRowChanged.connect(lambda *_: self.show_el()); c2.addWidget(self.le, 1)
        b = QtWidgets.QHBoxLayout(); c2.addLayout(b); b.addWidget(button('Duplica', self.dup)); b.addWidget(button('Elimina', self.delete))
        c3 = QtWidgets.QVBoxLayout(); h.addLayout(c3, 3); f = QtWidgets.QFormLayout(); c3.addLayout(f)
        self.eN = QtWidgets.QLineEdit(); self.eN.editingFinished.connect(self.read); f.addRow('Nome', self.eN)
        hs = QtWidgets.QHBoxLayout(); self.eS = []
        for _ in range(3):
            e = QtWidgets.QLineEdit(); e.setMaximumWidth(70); e.editingFinished.connect(self.read); hs.addWidget(e); self.eS.append(e)
        self.bC = ColorButton(); self.bC.changed.connect(lambda *_: self.read()); hs.addWidget(self.bC); hs.addStretch(1)
        f.addRow("Larghezza, profondita', altezza (m) e colore", hs)
        self.cF = QtWidgets.QCheckBox('Fisso (in tutte le scene)'); self.cF.toggled.connect(lambda *_: self.read())
        f.addRow('', self.cF)
        hp = QtWidgets.QHBoxLayout(); self.eP = []
        for _ in range(3):
            e = QtWidgets.QLineEdit(); e.setMaximumWidth(70); e.editingFinished.connect(self.read); hp.addWidget(e); self.eP.append(e)
        hp.addStretch(1); f.addRow('Posizione X, Y (m) e rotazione (gradi)', hp)
        f.addRow('', label('X = 0 al centro, Y = 0 sul bordo del palco (proscenio escluso), Y cresce verso il fondale.', 'dim', True))
        self.eO = QtWidgets.QPlainTextEdit(); self.eO.setMaximumHeight(90); f.addRow('Occorrente', self.eO)
        self.eH = QtWidgets.QPlainTextEdit(); self.eH.setMaximumHeight(130); f.addRow('Come costruirlo', self.eH)
        self.eO.textChanged.connect(self.read_text); self.eH.textChanged.connect(self.read_text)
        self.prev = Preview3D(); self.prev.setMinimumSize(180, 200); c2.addWidget(self.prev, 1)
        self.fill(); self.show_el()

    def cur(self):
        r = self.le.currentRow(); E = self.app.sh['elements']
        return r if 0 <= r < len(E) else -1

    def fill(self, sel=None):
        E = self.app.sh['elements']; r = self.le.currentRow() if sel is None else sel
        self.le.blockSignals(True); self.le.clear()
        for e in E:
            self.le.addItem(e['name'] + ('  [fisso]' if e['fixed'] else ''))
        self.le.setCurrentRow(max(0, min(r, len(E) - 1)) if E else -1); self.le.blockSignals(False)

    def unique(self, base):
        names = [e['name'] for e in self.app.sh['elements']]; nm = base; k = 2
        while nm in names:
            nm = '%s %d' % (base, k); k += 1
        return nm

    def add_lib(self):
        r = self.lc.currentRow()
        if r < 0:
            return
        c = self.cat[r]
        self.app.sh['elements'].append(M.new_element(self.unique(c['name']), 'lib', c['id'], c['size'], c['rgb'], bool(c['hex'])))
        self.fill(len(self.app.sh['elements']) - 1); self.show_el()

    def add_import(self):
        f, bb, nm = import_dialog(self, self.app.folder)
        if f:
            self.app.sh['elements'].append(M.new_element(self.unique(nm), 'import', f, bb, [0.6, 0.5, 0.4], False))
            self.fill(len(self.app.sh['elements']) - 1); self.show_el()

    def dup(self):
        i = self.cur()
        if i >= 0:
            e = copy.deepcopy(self.app.sh['elements'][i]); e['name'] = self.unique(e['name'])
            self.app.sh['elements'].append(e); self.fill(len(self.app.sh['elements']) - 1); self.show_el()

    def delete(self):
        i = self.cur()
        if i < 0:
            return
        nm = self.app.sh['elements'][i]['name']
        used = any(o['kind'] == 'el' and o['ref'] == nm for sc in self.app.sh['scenes'] for o in sc['objects'])
        if used and not confirm(self, '"%s" e\' usato in alcune scene: eliminandolo sparisce anche da li\'. Continuare?' % nm):
            return
        M.remove_from_scenes(self.app.sh, 'el', nm); del self.app.sh['elements'][i]; self.fill(); self.show_el()

    def show_el(self):
        i = self.cur(); on = i >= 0
        for w in [self.eN, self.bC, self.cF, self.eO, self.eH] + self.eS + self.eP:
            w.setEnabled(on)
        if not on:
            self.prev.show_parts([]); return
        e = self.app.sh['elements'][i]; self._fill = True
        self.eN.setText(e['name'])
        for k in range(3):
            self.eS[k].setText('%.2f' % e['size'][k])
        self.cF.setChecked(e['fixed']); self.eP[0].setText('%.2f' % e['x']); self.eP[1].setText('%.2f' % e['y']); self.eP[2].setText('%g' % e['rot'])
        for w in self.eP:
            w.setEnabled(e['fixed'])
        self.bC.set_rgb(e['rgb']); self.bC.setEnabled(e['tint'])
        self.eO.setPlainText(e['occ']); self.eH.setPlainText(e['how']); self._fill = False
        self.prev.show_parts(L.element_parts(self.app.folder, e), elev=18, azim=-60)

    def read(self):
        i = self.cur()
        if i < 0 or self._fill:
            return
        e = self.app.sh['elements'][i]; old = e['name']; nm = self.eN.text().strip()
        if nm and nm != old and all(x['name'] != nm for x in self.app.sh['elements']):
            e['name'] = nm; M.rename_in_scenes(self.app.sh, 'el', old, nm)
        for k in range(3):
            v = num(self.eS[k].text(), 0)
            if v > 0:
                e['size'][k] = v
        e['fixed'] = self.cF.isChecked()
        e['x'] = num(self.eP[0].text(), e['x']); e['y'] = num(self.eP[1].text(), e['y']); e['rot'] = num(self.eP[2].text(), e['rot'])
        if e['fixed'] and e['x'] == 0 and e['y'] == 0:
            e['y'] = self.app.sh['theater']['D'] - e['size'][1] / 2 - 0.1
        e['rgb'] = self.bC.rgb
        self.fill(); self.show_el()

    def read_text(self):
        i = self.cur()
        if i >= 0 and not self._fill:
            e = self.app.sh['elements'][i]; e['occ'] = self.eO.toPlainText(); e['how'] = self.eH.toPlainText()


# ------------------------------------------------------------------ personaggi e costumi
class CharsTab(QtWidgets.QWidget):
    def __init__(self, app):
        super().__init__(); self.app = app; self._fill = False
        CAT = L.read_catalog()
        h = QtWidgets.QHBoxLayout(self)
        c1 = QtWidgets.QVBoxLayout(); h.addLayout(c1, 2)
        c1.addWidget(label('Personaggi', 'title'))
        self.lp = QtWidgets.QListWidget(); self.lp.currentRowChanged.connect(lambda *_: self.show_char()); c1.addWidget(self.lp, 1)
        c1.addWidget(button('+ Nuovo personaggio', self.add_char, True))
        b = QtWidgets.QHBoxLayout(); c1.addLayout(b); b.addWidget(button('Duplica', self.dup_char)); b.addWidget(button('Elimina', self.del_char))
        mid = QtWidgets.QVBoxLayout(); h.addLayout(mid, 6)
        g = QtWidgets.QGridLayout(); mid.addLayout(g)
        self.eNm = QtWidgets.QLineEdit(); self.eNm.editingFinished.connect(self.read_char)
        self.bPw = ColorButton(title='Colore della pedina'); self.bPw.changed.connect(lambda *_: self.read_char())
        self.pSx = QtWidgets.QComboBox(); self.pSx.addItems(['Uomo', 'Donna']); self.pSx.currentIndexChanged.connect(lambda *_: self.read_char())
        self.eHt = QtWidgets.QLineEdit(); self.eHt.setMaximumWidth(60); self.eHt.editingFinished.connect(self.read_char)
        self.pSk = QtWidgets.QComboBox(); self.pSk.addItems([s[0] for s in M.SKINS] + ['Personalizzata...']); self.pSk.currentIndexChanged.connect(self.read_skin)
        self.bSk = ColorButton(title='Colore della pelle'); self.bSk.changed.connect(self.skin_custom)
        self.pEy = QtWidgets.QComboBox(); self.pEy.addItems([e[0] for e in M.EYES]); self.pEy.currentIndexChanged.connect(lambda *_: self.read_char())
        g.addWidget(QtWidgets.QLabel('Nome'), 0, 0); g.addWidget(self.eNm, 0, 1); g.addWidget(QtWidgets.QLabel('Pedina'), 0, 2); g.addWidget(self.bPw, 0, 3)
        g.addWidget(QtWidgets.QLabel('Corpo'), 1, 0); g.addWidget(self.pSx, 1, 1); g.addWidget(QtWidgets.QLabel('Altezza'), 1, 2); g.addWidget(self.eHt, 1, 3)
        g.addWidget(QtWidgets.QLabel('Pelle'), 2, 0); g.addWidget(self.pSk, 2, 1); g.addWidget(self.bSk, 2, 3)
        g.addWidget(QtWidgets.QLabel('Occhi'), 3, 0); g.addWidget(self.pEy, 3, 1)
        self.eHt.setToolTip('Altezza in metri')
        mid.addWidget(label('COSTUMI', 'head'))
        hc = QtWidgets.QHBoxLayout(); mid.addLayout(hc)
        self.lc = QtWidgets.QListWidget(); self.lc.setMaximumHeight(110); self.lc.currentRowChanged.connect(lambda *_: self.show_costume()); hc.addWidget(self.lc, 2)
        vb = QtWidgets.QVBoxLayout(); hc.addLayout(vb, 1)
        for t, cb in (('+ Costume', self.add_costume), ('Duplica', self.dup_costume), ('Descrizione', self.desc_costume), ('Elimina', self.del_costume)):
            vb.addWidget(button(t, cb))
        vm = QtWidgets.QVBoxLayout(); hc.addLayout(vm, 2)
        vm.addWidget(QtWidgets.QLabel('Il costume viene'))
        self.pMd = QtWidgets.QComboBox(); self.pMd.addItems(['dalla libreria', 'da un modello importato']); self.pMd.currentIndexChanged.connect(self.read_mode)
        vm.addWidget(self.pMd); self.bIm = button('Importa modello 3D...', self.import_costume, tip='File .glb, .obj o .npz'); vm.addWidget(self.bIm)
        self.tIm = label('', 'dim'); vm.addWidget(self.tIm); vm.addStretch(1)
        cols = QtWidgets.QHBoxLayout(); mid.addLayout(cols, 1)
        gs = QtWidgets.QGridLayout(); cols.addLayout(gs, 1); gs.addWidget(label('CAPI  (colore con il quadratino)', 'head'), 0, 0, 1, 3)
        self.pIt = []; self.bIt = []; self.itemIds = []
        for q in range(M.NSLOT):
            cc = [c for c in CAT if c['cat'] == M.SLOTS[q]]
            self.itemIds.append([''] + [c['id'] for c in cc])
            cb = QtWidgets.QComboBox(); cb.addItems(['(— nessuno)'] + [c['name'] for c in cc]); cb.currentIndexChanged.connect(lambda *_: self.read_costume())
            bt = ColorButton(title=M.SLOTLBL[q]); bt.changed.connect(lambda rgb, q=q: self.item_colour(q, rgb))
            gs.addWidget(QtWidgets.QLabel(M.SLOTLBL[q]), q + 1, 0); gs.addWidget(cb, q + 1, 1); gs.addWidget(bt, q + 1, 2)
            self.pIt.append(cb); self.bIt.append(bt)
        self.cat_rgb = {c['id']: c['rgb'] for c in CAT if c['hex']}
        gm = QtWidgets.QGridLayout(); cols.addLayout(gm, 1); gm.addWidget(label('TRUCCO E PARRUCCO', 'head'), 0, 0, 1, 3)
        hc_ = [c for c in CAT if c['cat'] == 'Capelli']; bc_ = [c for c in CAT if c['cat'] == 'Barba']
        self.hairIds = [''] + [c['id'] for c in hc_]; self.facIds = [''] + [c['id'] for c in bc_]
        self.pHr = QtWidgets.QComboBox(); self.pHr.addItems(['Calvo / rasato'] + [c['name'] for c in hc_])
        self.pFc = QtWidgets.QComboBox(); self.pFc.addItems(['Nessuna'] + [c['name'] for c in bc_])
        self.pBr = QtWidgets.QComboBox(); self.pBr.addItems(M.BROWS)
        self.bHr = ColorButton(title='Capelli'); self.bFc = ColorButton(title='Barba'); self.bBr = ColorButton(title='Sopracciglia')
        for r, (t, cb, bt, key) in enumerate((('Capelli', self.pHr, self.bHr, 'hair'), ('Barba / baffi', self.pFc, self.bFc, 'facial'),
                                              ('Sopracciglia', self.pBr, self.bBr, 'brows')), 1):
            cb.currentIndexChanged.connect(lambda *_: self.read_costume()); bt.changed.connect(lambda rgb, key=key: self.mk_colour(key, rgb))
            gm.addWidget(QtWidgets.QLabel(t), r, 0); gm.addWidget(cb, r, 1); gm.addWidget(bt, r, 2)
        self.cMk = []; self.bMk = []
        for r, (key, t) in enumerate(M.MAKEUP, 4):
            ch = QtWidgets.QCheckBox(t); ch.toggled.connect(lambda *_: self.read_costume())
            bt = ColorButton(title=t); bt.changed.connect(lambda rgb, key=key: self.mk_colour(key, rgb))
            gm.addWidget(ch, r, 0, 1, 2); gm.addWidget(bt, r, 2); self.cMk.append(ch); self.bMk.append(bt)
        gm.addWidget(label('Un "Abito intero" sostituisce maglia e pantaloni. Anteprima: trascina per ruotare, rotella per lo zoom.', 'dim', True), 9, 0, 1, 3)
        gm.setRowStretch(10, 1)
        self.prev = Preview3D(); self.prev.setMinimumSize(180, 220); c1.addWidget(self.prev, 2)
        self.lib_widgets = self.pIt + self.bIt + [self.pHr, self.pFc, self.pBr, self.bHr, self.bFc, self.bBr] + self.cMk + self.bMk
        self.fill(); self.show_char()

    # ---- personaggi
    def fill(self, sel=None):
        C = self.app.sh['chars']; r = self.lp.currentRow() if sel is None else sel
        self.lp.blockSignals(True); self.lp.clear(); self.lp.addItems([c['name'] for c in C])
        self.lp.setCurrentRow(max(0, min(r, len(C) - 1)) if C else -1); self.lp.blockSignals(False)

    def ch(self):
        r = self.lp.currentRow(); C = self.app.sh['chars']
        return C[r] if 0 <= r < len(C) else None

    def co(self):
        c = self.ch()
        if not c:
            return None
        j = self.lc.currentRow()
        return c['costumes'][j] if 0 <= j < len(c['costumes']) else c['costumes'][0]

    def touch(self):
        c = self.ch()
        if c:
            c['rev'] += 1

    def add_char(self):
        a = ask_text(self, 'Nuovo personaggio', ['Nome del personaggio', 'Corpo (U = uomo, D = donna)'], ['', 'U'])
        if not a or not a[0]:
            return
        if M.find_char(self.app.sh, a[0]):
            error(self, "Esiste gia' un personaggio con questo nome."); return
        sex = 'F' if a[1][:1].upper() == 'D' else 'M'
        self.app.sh['chars'].append(M.new_char(a[0], sex, len(self.app.sh['chars']) + 1)); self.fill(len(self.app.sh['chars']) - 1); self.show_char()

    def dup_char(self):
        c = self.ch()
        if not c:
            return
        n = copy.deepcopy(c); n['name'] = c['name'] + ' 2'
        while M.find_char(self.app.sh, n['name']):
            n['name'] += '+'
        self.app.sh['chars'].append(n); self.fill(len(self.app.sh['chars']) - 1); self.show_char()

    def del_char(self):
        c = self.ch()
        if c and confirm(self, 'Eliminare "%s"? Sparira\' anche da tutte le scene.' % c['name']):
            M.remove_from_scenes(self.app.sh, 'char', c['name']); self.app.sh['chars'].remove(c); self.fill(); self.show_char()

    def show_char(self):
        c = self.ch(); on = c is not None
        for w in [self.eNm, self.bPw, self.pSx, self.eHt, self.pSk, self.pEy, self.lc, self.pMd, self.bIm] + self.lib_widgets:
            w.setEnabled(on)
        if not on:
            self.prev.show_parts([]); self.lc.clear(); return
        self._fill = True
        self.eNm.setText(c['name']); self.bPw.set_rgb(c['pawn']); self.pSx.setCurrentIndex(1 if c['sex'] == 'F' else 0)
        self.eHt.setText('%.2f' % c['height'])
        k = next((i for i, s in enumerate(M.SKINS) if max(abs(a - b) for a, b in zip(s[1], c['skin'])) < 0.02), len(M.SKINS))
        self.pSk.setCurrentIndex(k); self.bSk.set_rgb(c['skin'])
        self.pEy.setCurrentIndex(min(range(len(M.EYES)), key=lambda i: sum((a - b) ** 2 for a, b in zip(M.EYES[i][1], c['eyes']))))
        j = max(0, self.lc.currentRow()); self.lc.clear()
        self.lc.addItems(['%s  -  %s' % (x['code'], M.short_desc(x)) for x in c['costumes']]); self.lc.setCurrentRow(min(j, len(c['costumes']) - 1))
        self._fill = False
        self.show_costume()

    def read_char(self):
        c = self.ch()
        if not c or self._fill:
            return
        old = c['name']; nm = self.eNm.text().strip()
        if nm and nm != old and not M.find_char(self.app.sh, nm):
            c['name'] = nm; M.rename_in_scenes(self.app.sh, 'char', old, nm)
        c['pawn'] = self.bPw.rgb; c['sex'] = 'F' if self.pSx.currentIndex() == 1 else 'M'
        h = num(self.eHt.text(), c['height'])
        if 0.5 < h < 2.6:
            c['height'] = h
        c['eyes'] = M.EYES[self.pEy.currentIndex()][1]
        self.touch(); r = self.lp.currentRow(); self.fill(r); self.show_char()

    def read_skin(self):
        c = self.ch()
        if not c or self._fill:
            return
        k = self.pSk.currentIndex()
        if k < len(M.SKINS):
            c['skin'] = list(M.SKINS[k][1]); self.touch(); self.show_char()
        else:
            self.bSk.click()

    def skin_custom(self, rgb):
        c = self.ch()
        if c:
            c['skin'] = rgb; self.touch(); self.show_char()

    # ---- costumi
    def add_costume(self):
        c = self.ch()
        if not c:
            return
        n = copy.deepcopy(c['costumes'][-1]); n['code'] = chr(ord('A') + len(c['costumes'])); n['desc'] = 'costume ' + n['code']
        c['costumes'].append(n); self.touch(); self.show_char(); self.lc.setCurrentRow(len(c['costumes']) - 1)

    def dup_costume(self):
        c = self.ch(); co = self.co()
        if not co:
            return
        n = copy.deepcopy(co); n['code'] = chr(ord('A') + len(c['costumes'])); n['desc'] += ' (copia)'
        c['costumes'].append(n); self.show_char(); self.lc.setCurrentRow(len(c['costumes']) - 1)

    def desc_costume(self):
        co = self.co()
        if not co:
            return
        a = ask_text(self, 'Costume', ['Descrizione del costume'], [co['desc']])
        if a:
            j = self.lc.currentRow(); co['desc'] = a[0]; self.show_char(); self.lc.setCurrentRow(j)

    def del_costume(self):
        c = self.ch(); co = self.co()
        if not co:
            return
        if len(c['costumes']) == 1:
            error(self, 'Ogni personaggio ha almeno un costume.'); return
        c['costumes'].remove(co)
        for i, x in enumerate(c['costumes']):
            x['code'] = chr(ord('A') + i)
        self.touch(); self.lc.setCurrentRow(0); self.show_char()

    def show_costume(self):
        co = self.co()
        if not co or self._fill:
            return
        self._fill = True
        lib = co['mode'] == 'lib'
        self.pMd.setCurrentIndex(0 if lib else 1); self.bIm.setEnabled(not lib); self.tIm.setText('' if lib else 'File: ' + co['file'])
        for w in self.lib_widgets:
            w.setEnabled(lib)
        for q in range(M.NSLOT):
            ids = self.itemIds[q]
            self.pIt[q].setCurrentIndex(ids.index(co['items'][q]) if co['items'][q] in ids else 0); self.bIt[q].set_rgb(co['irgb'][q])
        self.pHr.setCurrentIndex(self.hairIds.index(co['hair']) if co['hair'] in self.hairIds else 0); self.bHr.set_rgb(co['hairRGB'])
        self.pFc.setCurrentIndex(self.facIds.index(co['facial']) if co['facial'] in self.facIds else 0); self.bFc.set_rgb(co['facialRGB'])
        self.pBr.setCurrentText(co['mk']['brows']); self.bBr.set_rgb(co['mk']['browsRGB'])
        for (key, _), ch, bt in zip(M.MAKEUP, self.cMk, self.bMk):
            ch.setChecked(bool(co['mk'][key])); bt.set_rgb(co['mk'][key + 'RGB'])
        self._fill = False
        self.preview()

    def preview(self):
        c = self.ch(); co = self.co()
        if not c or not co:
            return
        QtWidgets.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
        try:
            self.prev.show_parts(L.char_parts(self.app.sh, self.app.folder, c, co['code']), elev=6, azim=-70)
        finally:
            QtWidgets.QApplication.restoreOverrideCursor()

    def read_mode(self):
        co = self.co()
        if not co or self._fill:
            return
        co['mode'] = 'lib' if self.pMd.currentIndex() == 0 else 'import'
        if co['mode'] == 'import' and not co['file']:
            self.import_costume(); return
        self.touch(); self.show_costume()

    def import_costume(self):
        co = self.co()
        if not co:
            return
        f, _, _ = import_dialog(self, self.app.folder)
        if f:
            co['mode'] = 'import'; co['file'] = f
        elif not co['file']:
            co['mode'] = 'lib'
        self.touch(); self.show_costume()

    def read_costume(self):
        co = self.co()
        if not co or self._fill:
            return
        for q in range(M.NSLOT):
            nid = self.itemIds[q][self.pIt[q].currentIndex()]
            if nid != co['items'][q] and nid in self.cat_rgb:
                co['irgb'][q] = list(self.cat_rgb[nid])
            co['items'][q] = nid
        co['hair'] = self.hairIds[self.pHr.currentIndex()]; co['facial'] = self.facIds[self.pFc.currentIndex()]
        co['mk']['brows'] = self.pBr.currentText()
        for (key, _), ch in zip(M.MAKEUP, self.cMk):
            co['mk'][key] = 1 if ch.isChecked() else 0
        self.touch(); self.show_costume()

    def item_colour(self, q, rgb):
        co = self.co()
        if co:
            co['irgb'][q] = rgb; self.touch(); self.preview()

    def mk_colour(self, key, rgb):
        co = self.co()
        if not co:
            return
        if key == 'hair':
            co['hairRGB'] = rgb
        elif key == 'facial':
            co['facialRGB'] = rgb
        elif key == 'brows':
            co['mk']['browsRGB'] = rgb
        else:
            co['mk'][key + 'RGB'] = rgb; co['mk'][key] = 1
        self.touch(); self.show_costume()
