"""Editor di un passo: azioni (movimenti, entrate, uscite), occhi di bue che seguono, luci generali."""
import copy
import math

from PySide6 import QtWidgets

from . import model as M
from .planview import PlanView
from .ui_common import button, error, fit_window, label, num, window_layout


class StepEditor(QtWidgets.QDialog):
    def __init__(self, win, k, is_new, parent=None):
        super().__init__(parent); self.win = win; self.k = k; self.is_new = is_new
        sh = win.app.sh; self.sh = sh; sc = win.sc(); self.T = sh['theater']
        self.eff = [] if is_new else copy.deepcopy(sc['steps'][k])
        desc = '' if is_new else M.cue_text(sc, k); ens = '' if is_new or k >= len(sc['ens']) else sc['ens'][k]
        self.objs = copy.deepcopy(sc['objects']); self.st0 = [list(r) for r in M.state_at(sc, k)]; self.cast = copy.deepcopy(sc['cast'])
        self.P = []; self.drawing = False; self.startPt = None
        self.tg = [('char', c['name'], c['name']) for c in sh['chars']] + \
                  [('el', e['name'], 'Elemento: ' + e['name']) for e in sh['elements'] if not e['fixed']]
        self.FOL = [l for l in sh['lights'] if l['zone'] == M.FOLLOW] or \
                   [M.new_light('Occhio di bue', 'Seguipersona (occhio di bue)', 1, 'Bianco', [1, 1, 0.95], M.FOLLOW)]
        self.WL = [l for l in sh['lights'] if l['zone'] != M.FOLLOW]
        self.setWindowTitle('Passo %d — %s' % (k + 1, sc['title'])); fit_window(self, 1450, 880)
        h = window_layout(self, QtWidgets.QHBoxLayout); left = QtWidgets.QVBoxLayout(); h.addLayout(left, 3)
        self.plan = PlanView(); self.plan.title = 'Pianta del palco  (pubblico in basso)'; self.plan.set_context(sh, win.app.folder)
        left.addWidget(self.plan, 1); self.hint = label('', 'hint', True); left.addWidget(self.hint)
        self.plan.pressed.connect(self.m_down); self.plan.moved.connect(self.m_move); self.plan.released.connect(self.m_up)
        r = QtWidgets.QVBoxLayout(); h.addLayout(r, 2)
        r.addWidget(label('Descrizione del passo', 'head')); self.eD = QtWidgets.QLineEdit(desc); r.addWidget(self.eD)
        r.addWidget(label('Corpo di ballo / note (facoltativo)', 'head')); self.eE = QtWidgets.QLineEdit(ens); r.addWidget(self.eE)
        r.addWidget(label('Azioni di questo passo (tutte insieme, salvo il ritardo)', 'head'))
        self.la = QtWidgets.QListWidget(); self.la.setMaximumHeight(130); r.addWidget(self.la)
        r.addWidget(button("Elimina l'azione selezionata", self.del_action))
        r.addWidget(label('NUOVA AZIONE', 'head'))
        f = QtWidgets.QFormLayout(); r.addLayout(f)
        self.pC = QtWidgets.QComboBox(); self.pC.addItems([t[2] for t in self.tg]); f.addRow('Chi / cosa', self.pC)
        self.pT = QtWidgets.QComboBox(); self.pT.addItems(['Movimento', 'Entra in scena', 'Esce di scena']); f.addRow('Azione', self.pT)
        self.pP = QtWidgets.QComboBox(); self.pP.addItems(['Linea retta', 'Percorso libero'])
        self.pP.setToolTip('Linea retta: clicca il punto di arrivo.  Percorso libero: tieni premuto e disegna.')
        f.addRow('Percorso', self.pP)
        self.pL = QtWidgets.QComboBox(); self.pL.addItems(['Nessuna'] + [l['name'] for l in self.FOL])
        self.pL.setToolTip('Un occhio di bue che fa lo stesso percorso (si spegne quando il personaggio esce)'); f.addRow('Luce che lo segue', self.pL)
        self.cS = QtWidgets.QCheckBox('Scegli la partenza'); self.cS.setToolTip('Il primo clic sulla pianta indica il punto di partenza'); f.addRow('', self.cS)
        hd = QtWidgets.QHBoxLayout(); self.eDur = QtWidgets.QLineEdit('2'); self.eDel = QtWidgets.QLineEdit('0')
        self.eDel.setToolTip("Secondi di attesa dall'inizio del passo (0 = parte insieme alle altre azioni)")
        hd.addWidget(QtWidgets.QLabel('Durata (s)')); hd.addWidget(self.eDur); hd.addWidget(QtWidgets.QLabel('Ritardo (s)')); hd.addWidget(self.eDel)
        f.addRow('', hd)
        for w in (self.pC, self.pT, self.pP):
            w.currentIndexChanged.connect(lambda *_: self.new_action())
        self.cS.toggled.connect(lambda *_: self.new_action())
        r.addWidget(button('+  Aggiungi questa azione', self.add_action, True, "Poi puoi aggiungerne un'altra che avviene in contemporanea"))
        r.addWidget(button('Cancella il disegno', self.new_action))
        r.addWidget(label("LUCI GENERALI DEL PASSO (Ctrl + clic per piu' luci)", 'head'))
        hw = QtWidgets.QHBoxLayout(); r.addLayout(hw)
        self.lw = QtWidgets.QListWidget(); self.lw.setSelectionMode(QtWidgets.QAbstractItemView.MultiSelection); self.lw.setMaximumHeight(140)
        self.lw.addItems(['%s  (%s, %s)' % (l['name'], l['cname'], l['zone']) for l in self.WL]); hw.addWidget(self.lw, 3)
        vw = QtWidgets.QVBoxLayout(); hw.addLayout(vw, 2)
        vw.addWidget(button('Come il passo precedente', self.wash_prev)); vw.addWidget(button('Buio (spegni tutto)', self.lw.clearSelection))
        vw.addWidget(label('Le luci selezionate restano accese durante il passo.', 'dim', True))
        b = QtWidgets.QHBoxLayout(); r.addLayout(b); b.addWidget(button('Salva passo', self.save, True)); b.addWidget(button('Annulla', self.reject))
        if not self.tg:
            error(self, 'Prima crea almeno un personaggio o un elemento scenico (finestra dello spettacolo).')
        self.wash_sel(); self.draw(); self.show_actions(); self.new_action()

    # ------------------------------------------------ utilita'
    def msg(self, s):
        self.hint.setText(s)

    def tg_index(self, t):
        kind, ref, _ = self.tg[t]
        return next((i for i, o in enumerate(self.objs) if o['kind'] == kind and o['ref'] == ref), None)

    def cur_pos(self, ip):
        c = self.st0[ip][:2]
        for e in self.eff:
            if e['spid'] == self.objs[ip]['id'] and e['cls'] == 'path':
                c = e['pts'][-1]
        return list(c)

    def cur_vis(self, ip):
        a = bool(self.st0[ip][2] > 0.5)
        for e in self.eff:
            if e['spid'] == self.objs[ip]['id']:
                if e['cls'] == 'entr':
                    a = True
                elif e['cls'] == 'exit':
                    a = False
        return a

    def add_obj(self, o):
        self.objs.append(o); self.st0.append([0, 0, 0]); return len(self.objs) - 1

    def add_target(self, t, pt):
        kind, ref, _ = self.tg[t]; sh = self.sh
        if kind == 'char':
            ch = M.find_char(sh, ref)
            ip = self.add_obj(M.new_obj(M.new_uid(sh), 'char', ref, ref, pt[0], pt[1], ch['pawn']))
            tmp = dict(cast=self.cast); M.set_cast(tmp, ref, M.cast_code(sh, tmp, ref))
        else:
            e = M.find_element(sh, ref)
            ip = self.add_obj(M.new_obj(M.new_uid(sh), 'el', ref, ref, pt[0], pt[1], M.plan_color(e), '', e['size'][0], e['size'][1], 0))
        return ip

    def light_obj(self, Lt, lab, center):
        for i, o in enumerate(self.objs):
            if o['kind'] == 'light' and o['label'] == lab:
                return i
        # una luce dello stesso tipo gia' accesa sul punto di partenza, non ancora legata a nessuno: si riusa quella
        # (altrimenti resterebbe una seconda luce ferma dove il personaggio era)
        for i, o in enumerate(self.objs):
            if o['kind'] == 'light' and o['ref'] == Lt['name'] and o['zone'] == M.FOLLOW and ' su ' not in o['label'] \
                    and self.cur_vis(i):
                p = self.cur_pos(i)
                if math.dist((o['x'] + p[0], o['y'] + p[1]), center) < 0.8:
                    o['label'] = lab; return i
        return self.add_obj(M.new_obj(M.new_uid(self.sh), 'light', Lt['name'], lab, center[0], center[1], Lt['rgb'], Lt['zone']))

    def draw(self):
        items = []; P = M.follow_pos(self.objs, [self.cur_pos(i) for i in range(len(self.objs))]) if self.objs else []
        for i, o in enumerate(self.objs):
            if not self.cur_vis(i) or (o['kind'] == 'light' and o['zone'] != M.FOLLOW):
                continue
            items.append((o, P[i][0], P[i][1], 1))
        paths = []
        for e in self.eff:
            if e['cls'] != 'path' or e['dur'] < 0.05:
                continue
            o = next((x for x in self.objs if x['id'] == e['spid']), None)
            if o and o['kind'] != 'light':
                paths.append(([(o['x'] + a, o['y'] + b) for a, b in e['pts']], o['rgb']))
        self.plan.paths = paths; self.plan.temp_path = list(self.P); self.plan.start_mark = self.startPt
        self.plan.set_items(items)

    def show_actions(self):
        self.la.clear()
        for e in self.eff:
            o = next((x for x in self.objs if x['id'] == e['spid']), None); nm = o['label'] if o else '?'
            v = {'path': 'si muove (%d punti)' % len(e['pts']), 'entr': 'entra / si accende'}.get(e['cls'], 'esce / si spegne')
            self.la.addItem('%s: %s  —  %.1f s, ritardo %.1f s' % (nm, v, e['dur'], e['delay']))
        if not self.eff:
            self.la.addItem('(nessuna azione)')

    def del_action(self):
        r = self.la.currentRow()
        if 0 <= r < len(self.eff):
            del self.eff[r]; self.show_actions(); self.new_action()

    def new_action(self):
        self.P = []; self.drawing = False; self.startPt = None
        if not self.tg:
            return
        t = self.pC.currentIndex(); ip = self.tg_index(t); ty = self.pT.currentIndex(); nm = self.tg[t][1]
        if ip is not None and not self.cur_vis(ip) and ty != 1:
            ip = None
        self.draw()
        if ip is not None:
            p = self.cur_pos(ip); self.plan.start_mark = (self.objs[ip]['x'] + p[0], self.objs[ip]['y'] + p[1]); self.plan.update()
        if ty == 0:
            if ip is None:
                self.msg("%s non e' in scena: clicca dove compare, poi indica il percorso." % nm)
            elif self.cS.isChecked():
                self.msg('Primo clic: punto di partenza. Poi indica il percorso.')
            elif self.pP.currentIndex() == 0:
                self.msg("Clicca sulla pianta il punto di arrivo (il cerchio giallo e' la partenza).")
            else:
                self.msg('Tieni premuto il mouse sulla pianta e disegna il percorso, poi rilascia.')
        elif ty == 1:
            self.msg('Clicca dove deve comparire (es. in una quinta). Poi premi "+ Aggiungi questa azione".')
        else:
            self.msg('Premi "+ Aggiungi questa azione": esce dalla posizione in cui si trova.')

    # ------------------------------------------------ mouse
    def m_down(self, x, y, btn):
        if not self.tg:
            return
        t = self.pC.currentIndex(); ty = self.pT.currentIndex(); ip = self.tg_index(t)
        ipv = ip if (ip is not None and self.cur_vis(ip)) else None
        need = ipv is None or self.cS.isChecked() or ty == 1
        if need and self.startPt is None:
            self.startPt = (x, y); self.plan.start_mark = self.startPt; self.plan.update()
            self.msg('Punto scelto. Premi "+ Aggiungi questa azione".' if ty == 1 else 'Partenza scelta: ora indica il percorso.')
            return
        if ty != 0:
            return
        s0 = self.startPt
        if s0 is None:
            p = self.cur_pos(ip); s0 = (self.objs[ip]['x'] + p[0], self.objs[ip]['y'] + p[1])
        self.P = [s0, (x, y)]; self.drawing = self.pP.currentIndex() == 1
        self.plan.temp_path = list(self.P); self.plan.update()
        if not self.drawing:
            self.msg('Percorso pronto: regola durata e ritardo, poi premi "+ Aggiungi questa azione".')

    def m_move(self, x, y):
        if self.drawing and math.dist(self.P[-1], (x, y)) > 0.05:
            self.P.append((x, y)); self.plan.temp_path = list(self.P); self.plan.update()

    def m_up(self, x, y):
        if self.drawing:
            self.drawing = False; self.msg('Percorso disegnato: premi "+ Aggiungi questa azione" (o "Cancella il disegno").')

    # ------------------------------------------------ azioni
    def add_action(self):
        if not self.tg:
            return
        t = self.pC.currentIndex(); ty = self.pT.currentIndex(); nm = self.tg[t][1]
        du = num(self.eDur.text(), 1.5); du = du if du > 0 else 1.5
        dl = max(0.0, num(self.eDel.text(), 0))
        ip = self.tg_index(t)
        if ty == 0 and len(self.P) < 2:
            self.msg('Prima indica il movimento sulla pianta.'); return
        if ip is None or not self.cur_vis(ip):
            if ty == 2:
                self.msg("%s non e' in scena." % nm); return
            if self.startPt is None:
                self.msg('Clicca sulla pianta il punto in cui compare: ' + nm); return
            if ip is None:
                ip = self.add_target(t, self.startPt)
            o = self.objs[ip]
            self.eff.append(M.mk_eff('path', o['id'], [self.cur_pos(ip), [self.startPt[0] - o['x'], self.startPt[1] - o['y']]], 0.01, dl))
            self.eff.append(M.mk_eff('entr', o['id'], [], 0.5, dl))
            if ty == 0:
                dl += 0.5
            if ty == 1:
                ty = -1
        o = self.objs[ip]; org = (o['x'], o['y'])
        if ty == 0:
            self.eff.append(M.mk_eff('path', o['id'], M.simplify_path([(a - org[0], b - org[1]) for a, b in self.P]), du, dl))
        elif ty == 1:
            if self.startPt is not None:
                self.eff.append(M.mk_eff('path', o['id'], [self.cur_pos(ip), [self.startPt[0] - org[0], self.startPt[1] - org[1]]], 0.01, dl))
            self.eff.append(M.mk_eff('entr', o['id'], [], du, dl))
        elif ty == 2:
            self.eff.append(M.mk_eff('exit', o['id'], [], du, dl))
            for i, x in enumerate(self.objs):
                if x['kind'] == 'light' and x['label'].endswith(' su ' + o['label']) and self.cur_vis(i):
                    self.eff.append(M.mk_eff('exit', x['id'], [], du, dl))
        sp = self.pL.currentIndex()
        if sp > 0 and ty == 0:
            Lt = self.FOL[sp - 1]; il = self.light_obj(Lt, Lt['name'] + ' su ' + o['label'], self.P[0])
            lo = self.objs[il]; lorg = (lo['x'], lo['y'])
            if not self.cur_vis(il):
                self.eff.append(M.mk_eff('path', lo['id'], [self.cur_pos(il), [self.P[0][0] - lorg[0], self.P[0][1] - lorg[1]]], 0.01, max(0, dl - 0.5)))
                self.eff.append(M.mk_eff('entr', lo['id'], [], 0.5, max(0, dl - 0.5)))
            self.eff.append(M.mk_eff('path', lo['id'], M.simplify_path([(a - lorg[0], b - lorg[1]) for a, b in self.P]), du, dl))
        if ty == 0 and o['kind'] == 'char':           # le luci gia' accese su questo personaggio lo seguono
            done = {e['spid'] for e in self.eff if e['cls'] == 'path'}
            for i, x in enumerate(self.objs):
                if x['kind'] == 'light' and x['label'].endswith(' su ' + o['label']) and x['id'] not in done and self.cur_vis(i):
                    self.eff.append(M.mk_eff('path', x['id'], M.simplify_path([(a - x['x'], b - x['y']) for a, b in self.P]), du, dl))
        self.show_actions(); self.new_action()
        self.msg('Azione aggiunta. Scegli un altro personaggio o elemento per farlo muovere in contemporanea, oppure "Salva passo".')

    # ------------------------------------------------ luci generali
    def wash_obj(self, q):
        return next((i for i, o in enumerate(self.objs) if o['kind'] == 'light' and o['label'] == self.WL[q]['name']), None)

    def wash_sel(self):
        for q in range(len(self.WL)):
            wi = self.wash_obj(q); self.lw.item(q).setSelected(bool(wi is not None and self.cur_vis(wi)))

    def wash_prev(self):
        for q in range(len(self.WL)):
            wi = self.wash_obj(q); self.lw.item(q).setSelected(bool(wi is not None and self.st0[wi][2] > 0.5))

    def apply_wash(self):
        sel = {i.row() for i in self.lw.selectedIndexes()}
        keep = []
        for e in self.eff:
            o = next((x for x in self.objs if x['id'] == e['spid']), None)
            if o and o['kind'] == 'light' and o['zone'] != M.FOLLOW and e['cls'] in ('entr', 'exit'):
                continue
            keep.append(e)
        self.eff = keep
        for q, Lt in enumerate(self.WL):
            on = q in sel; wi = self.wash_obj(q); before = wi is not None and self.st0[wi][2] > 0.5
            if on and not before:
                if wi is None:
                    g = M.zone_geom(Lt['zone'], self.T); wi = self.light_obj(Lt, Lt['name'], (g['cx'], g['cy']))
                self.eff.append(M.mk_eff('entr', self.objs[wi]['id'], [], 1.2, 0))
            elif not on and before:
                self.eff.append(M.mk_eff('exit', self.objs[wi]['id'], [], 1.2, 0))

    def save(self):
        self.apply_wash()
        sc = copy.deepcopy(self.win.sc()); sc['objects'] = self.objs; sc['cast'] = self.cast; n = len(sc['steps'])
        sc['cues'] = (sc['cues'] + [''] * n)[:n]; sc['ens'] = (sc['ens'] + [''] * n)[:n]
        dsc = self.eD.text().strip() or 'passo %d' % (self.k + 1); en = self.eE.text().strip(); k = self.k
        if self.is_new:
            sc['steps'].insert(k, self.eff); sc['cues'].insert(k, dsc); sc['ens'].insert(k, en)
        else:
            sc['steps'][k] = self.eff; sc['cues'][k] = dsc; sc['ens'][k] = en
        self.win.commit(sc); self.accept()
