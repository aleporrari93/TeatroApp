"""Finestra della scena: pianta / vista da pubblico, montaggio, musica, registrazione dei tempi, elenco passi."""
import math
import os
import tempfile
import time

import numpy as np
from PySide6 import QtCore, QtGui, QtWidgets
from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer

from . import model as M
from . import pdfout
from .planview import PlanView
from .ui_common import BG, button, confirm, error, info, label
from .view3d import Preview3D, Stage3D


class SceneWindow(QtWidgets.QWidget):
    def __init__(self, app):
        super().__init__(); self.app = app; self.idx = 0; self._quiet = False
        self.objs = []; self.pos = np.zeros((0, 2)); self.A = np.zeros(0)
        self.step = 0; self.running = False; self.anim = None; self.mode = None; self.view3 = False; self.built3 = False
        self.cueT = None; self.cueEnd = None; self.onsets = []; self.rec = False; self.recT = []; self.music = ''
        self.setWindowTitle('Scena'); self.resize(1300, 900)
        self.player = QMediaPlayer(self); self.audio = QAudioOutput(self); self.player.setAudioOutput(self.audio)
        self.player.positionChanged.connect(self.on_pos); self.player.durationChanged.connect(self.on_dur)
        self.timer = QtCore.QTimer(self); self.timer.setInterval(33); self.timer.timeout.connect(self.tick)
        self.watch = QtCore.QTimer(self); self.watch.setInterval(40); self.watch.timeout.connect(self.watch_music)
        lay = QtWidgets.QVBoxLayout(self)
        top = QtWidgets.QHBoxLayout(); lay.addLayout(top)
        top.addWidget(button('◀', lambda: self.go(self.idx - 1), tip='Scena precedente'))
        top.addWidget(button('Elenco passi', self.step_list, True))
        top.addWidget(button('Imposta scena', self.setup, tip="Chi c'e' all'inizio, con che costume, dove, e quali luci sono accese"))
        tv = QtWidgets.QVBoxLayout(); top.addLayout(tv, 1)
        self.ttl = label('', 'title'); self.ttl.setAlignment(QtCore.Qt.AlignCenter); tv.addWidget(self.ttl)
        self.sub = label('', 'dim'); self.sub.setAlignment(QtCore.Qt.AlignCenter); tv.addWidget(self.sub)
        top.addWidget(button('▶', lambda: self.go(self.idx + 1), tip='Scena successiva'))
        mid = QtWidgets.QHBoxLayout(); lay.addLayout(mid, 3)
        self.stack = QtWidgets.QStackedWidget(); mid.addWidget(self.stack, 4)
        self.plan = PlanView(); self.stack.addWidget(self.plan)
        w3 = QtWidgets.QWidget(); v3 = QtWidgets.QVBoxLayout(w3); v3.setContentsMargins(0, 0, 0, 0)
        cam = QtWidgets.QHBoxLayout(); v3.addLayout(cam)
        cam.addWidget(button('+', lambda: self.v3d.zoom(1 / 1.2), tip='Avvicina')); cam.addWidget(button('−', lambda: self.v3d.zoom(1.2), tip='Allontana'))
        cam.addWidget(button('↺ Vista di default', lambda: self.v3d.reset_camera()))
        cam.addWidget(label('Trascina: ruota  |  Ctrl + trascina o tasto centrale: sposta  |  rotella: zoom', 'dim')); cam.addStretch(1)
        self.v3d = Stage3D(); v3.addWidget(self.v3d, 1); self.stack.addWidget(w3)
        side = QtWidgets.QVBoxLayout(); mid.addLayout(side, 1)
        self.bView = button('Vista da pubblico', self.toggle_view, True, 'Palco visto dalla platea, con i personaggi in 3D'); side.addWidget(self.bView)
        g = QtWidgets.QGridLayout(); side.addLayout(g)
        g.addWidget(button('♪▶ Sync', lambda: self.sync(0), tip='Canzone e montaggio insieme (segue i tempi registrati)'), 0, 0)
        self.bRec = button('● Registra', self.record, tip='Premi la barra spaziatrice quando deve partire ogni passo'); g.addWidget(self.bRec, 0, 1)
        g.addWidget(button('▶▶  Montaggio', self.montage), 1, 0, 1, 2)
        g.addWidget(button('Passo singolo', self.next_step), 2, 0, 1, 2)
        g.addWidget(button('Ricomincia', self.reset), 3, 0); g.addWidget(button('Tempi passi', self.cue_table), 3, 1)
        g.addWidget(button('♪  Play', self.play), 4, 0); g.addWidget(button('❚❚  Pausa', self.player.pause), 4, 1)
        self.slider = QtWidgets.QSlider(QtCore.Qt.Horizontal); self.slider.sliderMoved.connect(self.seek); side.addWidget(self.slider)
        self.tlab = label('00:00 / --:--'); self.tlab.setAlignment(QtCore.Qt.AlignCenter); side.addWidget(self.tlab)
        side.addWidget(button('Costumi della scena', self.costumes))
        side.addWidget(button('Elenco scene', lambda: (self.app.show_win.show(), self.app.show_win.raise_()) if self.app.show_win else None))
        self.mlab = label('', 'dim', True); side.addWidget(self.mlab)
        self.snap = QtWidgets.QCheckBox('Aggancia alla battuta'); self.snap.setToolTip("Durante la registrazione sposta il tempo sull'attacco musicale piu' vicino")
        side.addWidget(self.snap); side.addStretch(1)
        self.comment = QtWidgets.QPlainTextEdit(); self.comment.setReadOnly(True); self.comment.setMaximumHeight(200); lay.addWidget(self.comment, 1)
        self.setFocusPolicy(QtCore.Qt.StrongFocus)

    # ------------------------------------------------ finestra
    def close_quiet(self):
        self._quiet = True; self.close()

    def closeEvent(self, ev):
        self.stop_all(); self.player.stop()
        if self.app.scene_win is self:
            self.app.scene_win = None
        ev.accept()

    def keyPressEvent(self, ev):
        k = ev.key()
        if k == QtCore.Qt.Key_Space:
            self.mark_cue() if self.rec else self.next_step()
        elif k == QtCore.Qt.Key_Right and not self.rec:
            self.go(self.idx + 1)
        elif k == QtCore.Qt.Key_Left and not self.rec:
            self.go(self.idx - 1)
        elif k == QtCore.Qt.Key_Escape and self.rec:
            self.stop_record(True)
        else:
            super().keyPressEvent(ev)

    def sc(self):
        return self.app.sh['scenes'][self.idx]

    def go_uid(self, uid):
        k = next((i for i, s in enumerate(self.app.sh['scenes']) if s['uid'] == uid), None)
        if k is not None:
            self.go(k)

    def reload(self):
        if self.app.sh['scenes']:
            self.go(min(self.idx, len(self.app.sh['scenes']) - 1))

    def go(self, k):
        S = self.app.sh['scenes']
        if not 0 <= k < len(S):
            return
        if self.rec:
            self.stop_record(False)
        self.stop_all(); self.player.stop()
        self.idx = k; sc = self.sc(); sh = self.app.sh
        self.setWindowTitle('Scena  -  ' + sc['title']); self.ttl.setText(sc['title'])
        self.sub.setText('Atto %s   ·   Scena %d   ·   %s' % (M.roman(sc['act']), sc['num'], sh['title']))
        self.objs = sc['objects']; n = len(self.objs); self.pos = np.zeros((n, 2)); self.A = np.zeros(n)
        self.plan.set_context(sh, self.app.folder)
        self.built3 = False
        if self.view3:
            self.build3d()
        self.music = M.find_music(self.app.folder, sc['num'])
        if self.music:
            self.player.setSource(QtCore.QUrl.fromLocalFile(self.music)); self.mlab.setText('Canzone: ' + os.path.basename(self.music))
            self.onsets = []; QtCore.QTimer.singleShot(100, self.compute_onsets)
        else:
            self.player.setSource(QtCore.QUrl()); self.mlab.setText('Canzone non trovata.\nMetti in "audio" un file che inizi con "%02d".' % sc['num'])
        self.load_cues()
        if self.cueT:
            self.mlab.setText(self.mlab.text() + '  (tempi registrati)')
        self.reset()
        self.comment.setPlainText('0  %s\n\n"Sync" = canzone e movimenti insieme;  "Montaggio" = tutta la scena;  '
                                  '"Passo singolo" (o barra spaziatrice) = un passo alla volta.' % M.start_text(sc))
        if self.app.show_win:
            self.app.show_win.lb.setCurrentRow(k)

    def setup(self):
        from .setup import SceneSetup
        SceneSetup(self.app, self.sc()['uid'], self).exec()

    # ------------------------------------------------ stato e disegno
    def redraw(self):
        self.plan.set_items([(o, self.pos[i, 0], self.pos[i, 1], self.A[i]) for i, o in enumerate(self.objs)])
        if self.view3 and self.built3:
            for i, o in enumerate(self.objs):
                self.v3d.place(i, o, self.pos[i, 0], self.pos[i, 1], self.A[i])

    def reset(self):
        self.stop_all(); self.step = 0
        self.pos[:] = 0; self.A = np.array([1.0 if o['start'] else 0.0 for o in self.objs])
        self.redraw(); self.comment.setPlainText('0  ' + M.start_text(self.sc()))

    def stop_all(self):
        self.timer.stop(); self.watch.stop(); self.anim = None; self.running = False; self.mode = None

    def fast_forward(self, m):
        st = M.state_at(self.sc(), m); self.pos = st[:, :2].copy(); self.A = st[:, 2].copy(); self.step = m; self.redraw()

    def build3d(self):
        QtWidgets.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
        try:
            self.v3d.build(self.app.sh, self.app.folder, self.sc()); self.built3 = True
        finally:
            QtWidgets.QApplication.restoreOverrideCursor()
        self.redraw()

    def toggle_view(self):
        self.view3 = not self.view3
        if self.view3:
            self.bView.setText("Vista dall'alto"); self.stack.setCurrentIndex(1)
            if not self.built3:
                self.build3d()
            self.redraw()
        else:
            self.bView.setText('Vista da pubblico'); self.stack.setCurrentIndex(0)

    # ------------------------------------------------ animazione
    def start_step(self, k, stretch=None):
        sc = self.sc(); ids = {o['id']: i for i, o in enumerate(self.objs)}
        eff = [dict(e) for e in sc['steps'][k] if e['spid'] in ids]
        T = max([e['delay'] + e['dur'] for e in eff] + [0])
        if stretch and T > 0 and stretch > 0.2:
            f = stretch / T
            for e in eff:
                e['delay'] *= f; e['dur'] *= f
            T = stretch
        self.anim = dict(eff=eff, idx=[ids[e['spid']] for e in eff], a0=self.A.copy(), t0=time.perf_counter(), T=T)
        self.running = True; self.step = k + 1
        txt = ['%d  %s' % (k + 1, M.cue_text(sc, k))]
        if k < len(sc['ens']) and sc['ens'][k]:
            txt.append('   ◆ Corpo di ballo: ' + sc['ens'][k])
        txt += M.describe_step(sc, k, self.app.sh['theater'])
        self.comment.setPlainText('\n'.join(txt))
        if not self.timer.isActive():
            self.timer.start()

    def finish_anim(self):
        """porta subito alla fine il passo in corso"""
        if not self.anim:
            return
        for e, i in zip(self.anim['eff'], self.anim['idx']):
            if e['cls'] == 'path':
                self.pos[i] = e['pts'][-1]
            elif e['cls'] == 'entr':
                self.A[i] = 1
            else:
                self.A[i] = 0
        self.anim = None; self.running = False; self.redraw()

    def tick(self):
        a = self.anim
        if a:
            t = time.perf_counter() - a['t0']
            for e, i in zip(a['eff'], a['idx']):
                u = min(max((t - e['delay']) / max(e['dur'], 0.01), 0), 1); u = 0.5 - 0.5 * math.cos(math.pi * u)
                if e['cls'] == 'path':
                    self.pos[i] = M.path_point(e['pts'], u)
                elif t >= e['delay']:
                    self.A[i] = max(a['a0'][i], u) if e['cls'] == 'entr' else min(a['a0'][i], 1 - u)
            self.redraw()
            if t > a['T']:
                self.anim = None; self.running = False
                if self.mode == 'montage':
                    if self.step < len(self.sc()['steps']):
                        QtCore.QTimer.singleShot(900, self.montage_next)
                    else:
                        self.mode = None; self.end_text()
        if not self.anim and self.mode not in ('sync', 'rec'):
            self.timer.stop()

    def end_text(self):
        self.comment.appendPlainText('\n— Fine della scena —')

    def next_step(self):
        if self.running or self.mode:
            return
        if self.step >= len(self.sc()['steps']):
            self.end_text(); return
        self.start_step(self.step)

    def montage(self):
        if self.mode or self.running:
            return
        if self.step >= len(self.sc()['steps']):
            self.reset()
        self.mode = 'montage'; self.montage_next()

    def montage_next(self):
        if self.mode != 'montage':
            return
        if self.step >= len(self.sc()['steps']):
            self.mode = None; self.end_text(); return
        self.start_step(self.step)

    # ------------------------------------------------ musica
    def on_dur(self, d):
        self.slider.setRange(0, int(d)); self.show_time(self.player.position())

    def on_pos(self, p):
        if not self.slider.isSliderDown():
            self.slider.setValue(int(p))
        self.show_time(p)

    def show_time(self, p):
        d = self.player.duration()
        f = lambda ms: '%02d:%02d' % (ms // 60000, (ms // 1000) % 60)
        self.tlab.setText('%s / %s' % (f(p), f(d) if d > 0 else '--:--'))

    def seek(self, v):
        self.player.setPosition(int(v))

    def have_music(self):
        if not self.music:
            sc = self.sc()
            info(self, 'Nessuna canzone per la scena %d.\nMetti nella cartella "audio" dello spettacolo un file che inizi con "%02d", ad esempio:\n'
                       '"%02d %s.mp3"' % (sc['num'], sc['num'], sc['num'], M.safe_name(sc['title'])), 'Canzone')
            return False
        return True

    def play(self):
        if self.have_music():
            self.player.play()

    def compute_onsets(self):
        """attacchi musicali, per agganciare i tempi alla battuta (solo se il file si puo' leggere)"""
        self.onsets = []
        try:
            if self.music.lower().endswith('.wav'):
                import wave
                w = wave.open(self.music); fs = w.getframerate(); n = w.getnframes(); ch = w.getnchannels(); sw = w.getsampwidth()
                raw = w.readframes(n); dt = {1: np.uint8, 2: np.int16, 4: np.int32}[sw]
                y = np.frombuffer(raw, dt).reshape(-1, ch).astype(float); self.onsets = M.detect_onsets(y, fs); return
            from PySide6.QtMultimedia import QAudioDecoder, QAudioFormat
            dec = QAudioDecoder(self); fmt = QAudioFormat(); fmt.setSampleRate(22050); fmt.setChannelCount(1); fmt.setSampleFormat(QAudioFormat.Int16)
            dec.setAudioFormat(fmt); dec.setSource(QtCore.QUrl.fromLocalFile(self.music)); chunks = []
            def ready():
                try:
                    b = dec.read(); chunks.append(np.frombuffer(bytes(b.constData()), np.int16).copy())
                except Exception:
                    pass
            def done():
                try:
                    if chunks:
                        self.onsets = M.detect_onsets(np.concatenate(chunks).astype(float), 22050)
                except Exception:
                    self.onsets = []
            dec.bufferReady.connect(ready); dec.finished.connect(done); dec.start(); self._dec = dec
        except Exception:
            self.onsets = []

    def snap_beat(self, t):
        if not self.onsets:
            return t
        o = np.asarray(self.onsets); i = int(np.argmin(abs(o - t)))
        return float(o[i]) if abs(o[i] - t) < 0.2 else t

    def load_cues(self):
        self.cueT, self.cueEnd = M.read_cues(M.cue_path(self.app.folder, self.sc()), len(self.sc()['steps']))

    def save_cues(self, T, E):
        M.write_cues(M.cue_path(self.app.folder, self.sc()), self.sc(), T, E); self.cueT, self.cueEnd = list(T), list(E)

    def sync(self, k0=0):
        if self.mode or self.running or not self.have_music():
            return
        self.reset(); n = len(self.sc()['steps'])
        dur = max(self.player.duration() / 1000, 1)
        self.load_cues()
        how = 'tempi registrati' if self.cueT else 'distribuiti in modo uniforme'
        self.tk = M.fill_cues(self.cueT if self.cueT else [float('nan')] * n, dur)
        k0 = max(0, min(k0, n - 1)) if n else 0
        if k0 > 0:
            self.fast_forward(k0)
        self.sync_k = k0; self.mode = 'sync'
        self.player.setPosition(int(max(0, self.tk[k0] - 3) * 1000) if k0 > 0 else 0); self.player.play()
        self.comment.appendPlainText('\nSync: %d passi, %s.' % (n, how))
        self.watch.start(); self.timer.start()

    def watch_music(self):
        t = self.player.position() / 1000; sc = self.sc(); n = len(sc['steps'])
        if self.mode == 'sync':
            if self.sync_k >= n:
                self.watch.stop(); self.mode = None; return
            if t >= self.tk[self.sync_k]:
                self.finish_anim(); k = self.sync_k; stretch = None
                if self.cueT and self.cueEnd and k < len(self.cueEnd) and not math.isnan(self.cueEnd[k]) and not math.isnan(self.cueT[k]):
                    stretch = self.cueEnd[k] - self.cueT[k]
                self.start_step(k, stretch); self.sync_k += 1
        elif self.mode == 'rec':
            if self.player.playbackState() != QMediaPlayer.PlayingState and t > 0.5:
                self.stop_record(True)

    def record(self):
        if self.rec:
            self.stop_record(True); return
        if self.mode or self.running:
            return
        sc = self.sc(); n = len(sc['steps'])
        if n == 0:
            info(self, 'Questa scena non ha passi da sincronizzare.'); return
        if not self.have_music():
            return
        self.reset(); self.load_cues(); self.rec = True; self.recT = [float('nan')] * n; self.mode = 'rec'
        self.bRec.setText('■ Stop'); self.setFocus()
        self.comment.setPlainText('REGISTRAZIONE TEMPI — %s\nPremi la BARRA SPAZIATRICE nel momento in cui deve partire ogni passo '
                                  '(il passo parte subito).\nPassi da segnare: %d.   Esc oppure "Stop" per terminare e salvare.\n\nProssimo: 1  %s'
                                  % (sc['title'], n, M.cue_text(sc, 0)))
        self.player.setPosition(0); self.player.play(); self.watch.start(); self.timer.start()

    def mark_cue(self):
        if not self.rec:
            return
        k = next((i for i, v in enumerate(self.recT) if math.isnan(v)), None)
        if k is None:
            return
        t = self.player.position() / 1000
        if self.snap.isChecked():
            t = self.snap_beat(t)
        self.recT[k] = t; self.finish_anim(); self.start_step(k)
        sc = self.sc()
        if k + 1 < len(sc['steps']):
            self.comment.appendPlainText('\nProssimo: %d  %s' % (k + 2, M.cue_text(sc, k + 1)))
        else:
            QtCore.QTimer.singleShot(1500, lambda: self.stop_record(True))

    def stop_record(self, save):
        if not self.rec:
            return
        self.rec = False; self.mode = None; self.watch.stop(); self.player.stop(); self.bRec.setText('● Registra')
        done = sum(0 if math.isnan(v) else 1 for v in self.recT)
        if save and done:
            E = list(self.cueEnd) if self.cueEnd and len(self.cueEnd) == len(self.recT) else [float('nan')] * len(self.recT)
            self.save_cues(self.recT, E)
            self.comment.appendPlainText('\nSalvati %d tempi su %d. Apri "Tempi passi" per correggerli. "Sync" ora segue questi tempi.' % (done, len(self.recT)))
            if 'registrati' not in self.mlab.text():
                self.mlab.setText(self.mlab.text() + '  (tempi registrati)')

    def cue_table(self):
        sc = self.sc()
        if not sc['steps']:
            info(self, 'Questa scena non ha passi.'); return
        CueTable(self).exec()

    # ------------------------------------------------ altro
    def costumes(self):
        sc = self.sc(); sh = self.app.sh; names = []
        for o in sc['objects']:
            if o['kind'] == 'char' and o['ref'] not in names:
                names.append(o['ref'])
        if not names:
            info(self, 'In questa scena non ci sono personaggi.'); return
        from . import library as L
        d = QtWidgets.QDialog(self); d.setWindowTitle('Costumi  -  ' + sc['title']); d.resize(min(1600, 320 * len(names)), 620)
        h = QtWidgets.QHBoxLayout(d)
        for nm in names:
            ch = M.find_char(sh, nm)
            if not ch:
                continue
            code = M.cast_code(sh, sc, nm); co = next((c for c in ch['costumes'] if c['code'] == code), ch['costumes'][0])
            v = QtWidgets.QVBoxLayout(); h.addLayout(v)
            p = Preview3D(); p.show_parts(L.char_parts(sh, self.app.folder, ch, code)); v.addWidget(p, 1)
            t = label('%s\ncostume %s: %s' % (nm, co['code'], co['desc'])); t.setAlignment(QtCore.Qt.AlignCenter); v.addWidget(t)
        d.exec()

    def step_list(self):
        if self.mode or self.running:
            return
        StepList(self).exec()

    def commit(self, sc):
        n = len(sc['steps']); sc['cues'] = (sc['cues'] + [''] * n)[:n]; sc['ens'] = (sc['ens'] + [''] * n)[:n]
        M.prune_objs(sc); self.app.sh['scenes'][self.idx] = sc; self.app.save()
        self.go(self.idx)
        if self.app.show_win:
            self.app.show_win.refresh(sc['uid'])

    def grab_3d(self, stv):
        """immagine della scena dalla platea, con gli oggetti dove compaiono per la prima volta"""
        was3 = self.view3
        if not self.view3:
            self.toggle_view()
        if not self.built3:
            self.build3d()
        for i, o in enumerate(self.objs):
            self.v3d.place(i, o, stv[i, 0], stv[i, 1], stv[i, 2])
        QtWidgets.QApplication.processEvents()
        img = self.v3d.grabFramebuffer()
        fn = os.path.join(tempfile.mkdtemp(), 'vista3d.png'); img.save(fn)
        self.redraw()
        if not was3:
            self.toggle_view()
        return fn

    def export_pdf(self):
        sc = self.sc()
        default = os.path.join(self.app.folder, M.safe_name('Atto %s - Scena %d - %s' % (M.roman(sc['act']), sc['num'], sc['title'])) + '.pdf')
        fn, _ = QtWidgets.QFileDialog.getSaveFileName(self, "Salva l'elenco dei passi in PDF", default, 'PDF (*.pdf)')
        if not fn:
            return
        try:
            self.load_cues(); img = self.grab_3d(M.first_appearance(sc))
            pdfout.scene_pdf(fn, self.app.sh, sc, self.cueT, img); info(self, 'PDF salvato in:\n' + fn)
        except Exception as e:
            error(self, 'Errore nella creazione del PDF: %s' % e)


class CueTable(QtWidgets.QDialog):
    def __init__(self, win):
        super().__init__(win); self.win = win; sc = win.sc(); n = len(sc['steps'])
        win.load_cues()
        self.T = list(win.cueT) if win.cueT else [float('nan')] * n; self.E = list(win.cueEnd) if win.cueEnd else [float('nan')] * n
        self.setWindowTitle('Tempi dei passi — ' + sc['title']); self.resize(900, 600)
        lay = QtWidgets.QVBoxLayout(self)
        lay.addWidget(label('Tempi nel formato mm:ss.d (es. 01:12.4). Seleziona una riga e usa i pulsanti per spostarla.\n'
                            '"Fine" vuota = durata scritta nel passo; se la scrivi, il movimento dura fino a quel momento.', 'head'))
        self.tb = QtWidgets.QTableWidget(n, 4); self.tb.setHorizontalHeaderLabels(['Passo', 'Inizio', 'Fine', 'Descrizione'])
        self.tb.horizontalHeader().setStretchLastSection(True); self.tb.verticalHeader().setVisible(False); lay.addWidget(self.tb, 1)
        self.tb.itemChanged.connect(self.edited)
        b = QtWidgets.QHBoxLayout(); lay.addLayout(b)
        for t, d in (('◀ 0,5 s', -0.5), ('◀ 0,1 s', -0.1), ('0,1 s ▶', 0.1), ('0,5 s ▶', 0.5)):
            b.addWidget(button(t, lambda d=d: self.nudge(d)))
        b.addWidget(button('▶ Ascolta da questo passo', self.listen)); b.addWidget(button('Aggancia alle battute', self.snap_all))
        b.addWidget(button('Riempi i vuoti', self.fill_gaps))
        b2 = QtWidgets.QHBoxLayout(); lay.addLayout(b2)
        b2.addWidget(button('Salva', self.save, True)); self.st = label('', 'dim'); b2.addWidget(self.st, 1); b2.addWidget(button('Chiudi', self.accept))
        self.fill()

    def fill(self):
        sc = self.win.sc(); self.tb.blockSignals(True)
        for k in range(len(self.T)):
            it = QtWidgets.QTableWidgetItem(str(k + 1)); it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable); self.tb.setItem(k, 0, it)
            self.tb.setItem(k, 1, QtWidgets.QTableWidgetItem(M.fmt_time(self.T[k]))); self.tb.setItem(k, 2, QtWidgets.QTableWidgetItem(M.fmt_time(self.E[k])))
            it = QtWidgets.QTableWidgetItem(M.cue_text(sc, k)); it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable); self.tb.setItem(k, 3, it)
        self.tb.blockSignals(False)

    def edited(self, it):
        r, c = it.row(), it.column(); v = M.parse_time(it.text())
        if c == 1:
            self.T[r] = v
        elif c == 2:
            self.E[r] = v
        self.st.setText('Modificato (premi Salva)')

    def sel(self):
        return max(0, self.tb.currentRow())

    def nudge(self, d):
        k = self.sel()
        if math.isnan(self.T[k]):
            self.st.setText('Questo passo non ha ancora un tempo'); return
        self.T[k] = max(0, self.T[k] + d)
        if not math.isnan(self.E[k]):
            self.E[k] += d
        self.fill(); self.tb.selectRow(k); self.st.setText('Passo %d  %s  (premi Salva)' % (k + 1, M.fmt_time(self.T[k])))

    def save(self):
        self.win.save_cues(self.T, self.E); self.st.setText('Salvato')
        if 'registrati' not in self.win.mlab.text():
            self.win.mlab.setText(self.win.mlab.text() + '  (tempi registrati)')

    def listen(self):
        k = self.sel(); self.save(); self.accept(); self.win.sync(k)

    def snap_all(self):
        if not self.win.onsets:
            self.st.setText('Attacchi musicali non disponibili per questo file.'); return
        self.T = [v if math.isnan(v) else self.win.snap_beat(v) for v in self.T]; self.fill()
        self.st.setText("Tempi agganciati all'attacco musicale piu' vicino (premi Salva)")

    def fill_gaps(self):
        d = self.win.player.duration() / 1000
        if d <= 0:
            self.st.setText('Prima premi Play una volta per leggere la durata della canzone.'); return
        self.T = list(M.fill_cues(self.T, d)); self.fill(); self.st.setText('Passi senza tempo riempiti tra quelli vicini (premi Salva)')


class StepList(QtWidgets.QDialog):
    def __init__(self, win):
        super().__init__(win); self.win = win; sc = win.sc()
        self.setWindowTitle('Elenco passi — ' + sc['title']); self.resize(900, 640)
        lay = QtWidgets.QVBoxLayout(self)
        lay.addWidget(label('Passi della scena: %s\nDoppio clic su un passo per modificarlo.' % sc['title'], 'head'))
        self.lb = QtWidgets.QListWidget(); self.lb.itemDoubleClicked.connect(lambda *_: self.edit()); lay.addWidget(self.lb, 1)
        b = QtWidgets.QHBoxLayout(); lay.addLayout(b)
        b.addWidget(button('+ Aggiungi passo', self.add, True)); b.addWidget(button('Modifica', self.edit)); b.addWidget(button('Elimina', self.delete))
        b.addWidget(button('▲ Su', lambda: self.move(-1))); b.addWidget(button('▼ Giù', lambda: self.move(1)))
        b.addWidget(button('▶ Prova il passo', self.try_step))
        b2 = QtWidgets.QHBoxLayout(); lay.addLayout(b2)
        b2.addWidget(button('⎙ Salva PDF', self.win.export_pdf, True, 'PDF: titolo e passi, poi la scena vista dalla platea'))
        self.st = label('', 'dim'); b2.addWidget(self.st, 1); b2.addWidget(button('Chiudi', self.accept))
        self.fill()

    def fill(self, sel=None):
        sc = self.win.sc(); r = self.lb.currentRow() if sel is None else sel; self.lb.clear()
        for k in range(len(sc['steps'])):
            self.lb.addItem('%2d.  %s   [%s]' % (k + 1, M.cue_text(sc, k), M.act_summary(sc, k)))
        if not sc['steps']:
            self.lb.addItem('(nessun passo: premi "+ Aggiungi passo")')
        self.lb.setCurrentRow(max(0, min(r, self.lb.count() - 1)))

    def k(self):
        return self.lb.currentRow() if self.win.sc()['steps'] else -1

    def add(self):
        from .stepedit import StepEditor
        k = self.k() + 1
        if StepEditor(self.win, k, True, self).exec():
            self.fill(k); self.st.setText('Passo %d salvato.' % (k + 1))

    def edit(self):
        from .stepedit import StepEditor
        k = self.k()
        if k >= 0 and StepEditor(self.win, k, False, self).exec():
            self.fill(k); self.st.setText('Passo %d salvato.' % (k + 1))

    def delete(self):
        k = self.k()
        if k < 0 or not confirm(self, 'Eliminare il passo %d?' % (k + 1), 'Elimina passo'):
            return
        import copy
        sc = copy.deepcopy(self.win.sc()); n = len(sc['steps'])
        sc['cues'] = (sc['cues'] + [''] * n)[:n]; sc['ens'] = (sc['ens'] + [''] * n)[:n]
        del sc['steps'][k], sc['cues'][k], sc['ens'][k]
        self.win.commit(sc); self.fill(); self.st.setText('Passo %d eliminato.' % (k + 1))

    def move(self, d):
        import copy
        k = self.k(); sc = copy.deepcopy(self.win.sc()); j = k + d; n = len(sc['steps'])
        if k < 0 or not 0 <= j < n:
            return
        sc['cues'] = (sc['cues'] + [''] * n)[:n]; sc['ens'] = (sc['ens'] + [''] * n)[:n]
        for key in ('steps', 'cues', 'ens'):
            sc[key][k], sc[key][j] = sc[key][j], sc[key][k]
        self.win.commit(sc); self.fill(j)

    def try_step(self):
        k = self.k()
        if k < 0:
            return
        self.win.raise_(); self.win.stop_all(); self.win.fast_forward(k); self.win.start_step(k)
