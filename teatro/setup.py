"""Imposta scena: chi c'e' all'inizio, con che costume, dove, e quali luci sono accese."""
import copy
import math

from PySide6 import QtWidgets

from . import model as M
from .planview import PlanView
from .ui_common import button, fit_window, label, window_layout


class SceneSetup(QtWidgets.QDialog):
    def __init__(self, app, uid, parent=None):
        super().__init__(parent); self.app = app; self.uid = uid; sh = app.sh
        self.sc = copy.deepcopy(next(s for s in sh['scenes'] if s['uid'] == uid))
        self.movable = [e for e in sh['elements'] if not e['fixed']]
        self.washes = [l for l in sh['lights'] if l['zone'] != M.FOLLOW]
        self.pending = None; self.drag = None
        self.setWindowTitle('Imposta scena  -  ' + self.sc['title']); fit_window(self, 1400, 840)
        h = window_layout(self, QtWidgets.QHBoxLayout); left = QtWidgets.QVBoxLayout(); h.addLayout(left, 3)
        self.plan = PlanView(); self.plan.title = "Posizioni all'inizio della scena  (pubblico in basso)"
        self.plan.set_context(sh, app.folder); left.addWidget(self.plan, 1)
        self.hint = label('', 'hint', True); left.addWidget(self.hint)
        self.plan.pressed.connect(self.m_down); self.plan.moved.connect(self.m_move); self.plan.released.connect(lambda *_: setattr(self, 'drag', None))
        r = QtWidgets.QVBoxLayout(); h.addLayout(r, 2)
        r.addWidget(label('Atto %s  -  Scena %d  -  %s' % (M.roman(self.sc['act']), self.sc['num'], self.sc['title']), 'head'))
        r.addWidget(label("PERSONAGGI  (in scena all'inizio = pallino pieno)", 'head'))
        hc = QtWidgets.QHBoxLayout(); r.addLayout(hc)
        self.lc = QtWidgets.QListWidget(); self.lc.currentRowChanged.connect(lambda *_: self.sel_char()); hc.addWidget(self.lc, 3)
        vc = QtWidgets.QVBoxLayout(); hc.addLayout(vc, 2)
        vc.addWidget(QtWidgets.QLabel('Costume in questa scena'))
        self.pco = QtWidgets.QComboBox(); self.pco.activated.connect(lambda *_: self.set_costume()); vc.addWidget(self.pco)
        vc.addWidget(button('Metti in scena / sposta', lambda: self.start_place('char')))
        vc.addWidget(button('Togli dalla scena', lambda: self.remove('char'))); vc.addStretch(1)
        r.addWidget(label('ELEMENTI SCENICI  (quelli "fissi" ci sono sempre)', 'head'))
        he = QtWidgets.QHBoxLayout(); r.addLayout(he)
        self.le = QtWidgets.QListWidget(); he.addWidget(self.le, 3)
        ve = QtWidgets.QVBoxLayout(); he.addLayout(ve, 2)
        ve.addWidget(button('Metti in scena / sposta', lambda: self.start_place('el')))
        ve.addWidget(button('Togli dalla scena', lambda: self.remove('el')))
        ve.addWidget(button('Ruota di 90°', self.rotate)); ve.addStretch(1)
        r.addWidget(label("LUCI ACCESE ALL'INIZIO  (Ctrl + clic per piu' luci)", 'head'))
        self.ll = QtWidgets.QListWidget(); self.ll.setSelectionMode(QtWidgets.QAbstractItemView.MultiSelection)
        for l in self.washes:
            self.ll.addItem('%s   (%s, %s)' % (l['name'], l['cname'], l['zone']))
        self.ll.itemSelectionChanged.connect(self.read_lights); r.addWidget(self.ll)
        r.addWidget(label("Chi entra piu' tardi non va messo qui: lo fai entrare nei passi. Clic su una pedina e trascina per spostarla.", 'dim', True))
        b = QtWidgets.QHBoxLayout(); r.addLayout(b)
        b.addWidget(button('Salva', self.save, True)); b.addWidget(button('Annulla', self.reject))
        for i, l in enumerate(self.washes):
            o = self.obj('light', l['name'])
            self.ll.item(i).setSelected(bool(o and o['start']))
        self.fill(); self.redraw(); self.msg('Scegli un personaggio o un elemento e premi "Metti in scena", poi clicca sulla pianta.')

    def msg(self, s):
        self.hint.setText(s)

    def obj(self, kind, ref):
        return next((o for o in self.sc['objects'] if o['kind'] == kind and o['ref'] == ref), None)

    def fill(self):
        sh = self.app.sh; r = self.lc.currentRow(); self.lc.blockSignals(True); self.lc.clear()
        for c in sh['chars']:
            o = self.obj('char', c['name']); on = bool(o and o['start'])
            self.lc.addItem('%s  %s   (costume %s)' % ('●' if on else '○', c['name'], M.cast_code(sh, self.sc, c['name'])))
        self.lc.setCurrentRow(max(0, r)); self.lc.blockSignals(False)
        r = self.le.currentRow(); self.le.clear()
        for e in self.movable:
            o = self.obj('el', e['name']); self.le.addItem('%s  %s' % ('●' if (o and o['start']) else '○', e['name']))
        self.le.setCurrentRow(max(0, r)); self.sel_char()

    def sel_char(self):
        r = self.lc.currentRow(); C = self.app.sh['chars']
        if not 0 <= r < len(C):
            return
        ch = C[r]; self.pco.clear(); self.pco.addItems(['%s  -  %s' % (x['code'], M.short_desc(x)) for x in ch['costumes']])
        code = M.cast_code(self.app.sh, self.sc, ch['name'])
        self.pco.setCurrentIndex(next((i for i, x in enumerate(ch['costumes']) if x['code'] == code), 0))

    def set_costume(self):
        r = self.lc.currentRow(); C = self.app.sh['chars']
        if 0 <= r < len(C):
            M.set_cast(self.sc, C[r]['name'], C[r]['costumes'][self.pco.currentIndex()]['code']); self.fill()

    def start_place(self, kind):
        if kind == 'char':
            r = self.lc.currentRow(); C = self.app.sh['chars']
            if not 0 <= r < len(C):
                return
            self.pending = ('char', C[r]['name'])
        else:
            r = self.le.currentRow()
            if not 0 <= r < len(self.movable):
                return
            self.pending = ('el', self.movable[r]['name'])
        self.msg("Clicca sulla pianta dove si trova all'inizio: " + self.pending[1])

    def remove(self, kind):
        if kind == 'char':
            r = self.lc.currentRow(); C = self.app.sh['chars']
            nm = C[r]['name'] if 0 <= r < len(C) else None
        else:
            r = self.le.currentRow(); nm = self.movable[r]['name'] if 0 <= r < len(self.movable) else None
        o = self.obj(kind, nm) if nm else None
        if o:
            o['start'] = False; M.prune_objs(self.sc); self.fill(); self.redraw()
            self.msg("%s non e' in scena all'inizio (puo' entrare durante i passi)." % nm)

    def rotate(self):
        r = self.le.currentRow()
        if not 0 <= r < len(self.movable):
            return
        o = self.obj('el', self.movable[r]['name'])
        if not o:
            self.msg('Prima mettilo in scena.'); return
        o['rot'] = (o['rot'] + 90) % 360; self.redraw()

    def read_lights(self):
        sh = self.app.sh; T = sh['theater']
        sel = {i.row() for i in self.ll.selectedIndexes()}
        for i, l in enumerate(self.washes):
            o = self.obj('light', l['name']); on = i in sel
            if on and o is None:
                g = M.zone_geom(l['zone'], T)
                self.sc['objects'].append(M.new_obj(M.new_uid(sh), 'light', l['name'], l['name'], g['cx'], g['cy'], l['rgb'], l['zone'], start=True))
            elif o is not None:
                o['start'] = on
        M.prune_objs(self.sc); self.redraw()

    def redraw(self):
        self.plan.set_items([(o, 0, 0, 1) for o in self.sc['objects'] if o['start']])

    def m_down(self, x, y, btn):
        sh = self.app.sh
        if self.pending:
            kind, ref = self.pending; o = self.obj(kind, ref)
            if o is None:
                if kind == 'char':
                    ch = M.find_char(sh, ref)
                    self.sc['objects'].append(M.new_obj(M.new_uid(sh), 'char', ref, ref, x, y, ch['pawn'], start=True))
                    M.set_cast(self.sc, ref, M.cast_code(sh, self.sc, ref))
                else:
                    e = M.find_element(sh, ref)
                    self.sc['objects'].append(M.new_obj(M.new_uid(sh), 'el', ref, ref, x, y, M.plan_color(e), '', e['size'][0], e['size'][1], 0, True))
            else:
                o.update(x=x, y=y, start=True)
            self.msg(ref + ' posizionato. Puoi trascinarlo per correggere.'); self.pending = None
            self.fill(); self.redraw(); return
        best = 0.6; self.drag = None
        for o in self.sc['objects']:
            if o['start'] and o['kind'] != 'light':
                d = math.dist((o['x'], o['y']), (x, y))
                if d < best:
                    best = d; self.drag = o

    def m_move(self, x, y):
        if self.drag is not None:
            self.drag['x'] = x; self.drag['y'] = y; self.redraw()

    def save(self):
        sh = self.app.sh
        for i, s in enumerate(sh['scenes']):
            if s['uid'] == self.uid:
                s['objects'] = self.sc['objects']; s['cast'] = self.sc['cast']; M.prune_objs(s)
        self.app.save()
        if self.app.show_win:
            self.app.show_win.refresh(self.uid)
        if self.app.scene_win:
            self.app.scene_win.reload()
        self.accept()
