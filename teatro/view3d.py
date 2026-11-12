"""Vista 3D (dalla platea e anteprime) con pyqtgraph.opengl."""
import math
import os

import numpy as np
import pyqtgraph.opengl as gl
from pyqtgraph import Vector
from PySide6 import QtGui

from . import library as L
from . import model as M


def merge_parts(P, translucent=False):
    """unisce le parti (opache o trasparenti) in una sola mesh: piu' veloce da disegnare"""
    Vs, Fs, Cs = [], [], []; off = 0
    for p in P:
        if (p['alpha'] < 0.99) != translucent or len(p['F']) == 0:
            continue
        Vs.append(p['V']); Fs.append(p['F'] + off)
        Cs.append(np.c_[p['C'], np.full(len(p['V']), p['alpha'])]); off += len(p['V'])
    if not Vs:
        return None
    return np.vstack(Vs).astype(np.float32), np.vstack(Fs).astype(np.int32), np.vstack(Cs).astype(np.float32)


def mesh_items(P):
    out = []
    for tr in (False, True):
        m = merge_parts(P, tr)
        if m is None:
            continue
        it = gl.GLMeshItem(vertexes=m[0], faces=m[1], vertexColors=m[2], smooth=True, shader='shaded',
                           glOptions='translucent' if tr else 'opaque')
        out.append(it)
    return out


class Obj3D:
    """gruppo di elementi 3D che si muovono insieme"""
    def __init__(self, items, rot=0.0, label=None, ztop=0.0, colour_item=None, base_alpha=1.0, rgb=(1, 1, 1)):
        self.items = items; self.rot = rot; self.label = label; self.ztop = ztop
        self.colour_item = colour_item; self.base_alpha = base_alpha; self.rgb = rgb

    def place(self, x, y, a):
        vis = a > 0.02
        for it in self.items:
            it.resetTransform()
            if self.rot:
                it.rotate(self.rot, 0, 0, 1)
            it.translate(x, y, 0)
            it.setVisible(vis)
        if self.colour_item is not None:
            self.colour_item.setColor((self.rgb[0], self.rgb[1], self.rgb[2], self.base_alpha * min(1.0, a)))
        if self.label is not None:
            self.label.setData(pos=(x, y, self.ztop))
            self.label.setVisible(a > 0.3)


def _quad(x0, x1, y0, y1, z0, z1, vertical=False):
    if vertical:
        V = np.array([[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]], np.float32)
    else:
        V = np.array([[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]], np.float32)
    return V, np.array([[0, 1, 2], [0, 2, 3]], np.int32)


def _flat(V, F, rgb, alpha=1.0, opts='opaque'):
    return gl.GLMeshItem(vertexes=V, faces=F, color=(rgb[0], rgb[1], rgb[2], alpha), smooth=False, shader=None, glOptions=opts)


class Stage3D(gl.GLViewWidget):
    """palco visto dalla platea"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setBackgroundColor((0, 0, 0)); self.objs = []; self.cam0 = None; self.camCur = None

    def clear_all(self):
        for it in list(self.items):
            self.removeItem(it)
        self.objs = []

    def build(self, sh, folder, sc, keep_camera=True):
        self.clear_all()
        T = sh['theater']; W, D, P, wg, H = T['W'], T['D'], T['P'], T['wing'], T['H']
        xa, xb = -W / 2 - wg, W / 2 + wg
        self.addItem(_flat(*_quad(xa, xb, -P, D, 0, 0), (0.36, 0.27, 0.19)))
        lines = []
        for yy in np.arange(-P, D + 0.01, 0.4):
            lines += [[xa, yy, 0.004], [xb, yy, 0.004]]
        self.addItem(gl.GLLinePlotItem(pos=np.array(lines), color=(0.25, 0.19, 0.13, 1), mode='lines', width=1))
        self.addItem(_flat(*_quad(xa, xb, -P, -P, -0.9, 0, True), (0.12, 0.10, 0.09)))
        qw = M.quinte_width(T)
        for yy in M.quinte_y(T):
            for sd in (-1, 1):
                a, b = sorted([sd * (W / 2 - 0.2), sd * (W / 2 - 0.2 + qw)])
                self.addItem(_flat(*_quad(a, b, yy, yy, 0, H, True), (0.06, 0.06, 0.07)))
        bc = {'Ciclorama bianco': (0.85, 0.85, 0.85), 'Grigio': (0.35, 0.35, 0.36)}.get(T['back'], (0.05, 0.05, 0.06))
        done = False
        if T['back'] == 'Immagine (foto o disegno)' and T['backImg']:
            try:
                from PIL import Image
                im = Image.open(os.path.join(folder, 'fondale', T['backImg'])).convert('RGBA')
                k = max(1, int(math.ceil(max(im.size) / 1024))); im = im.resize((im.size[0] // k, im.size[1] // k))
                arr = np.asarray(im)[::-1]                        # righe dal basso
                data = np.ascontiguousarray(np.transpose(arr, (1, 0, 2)))
                hI = min(H, (xb - xa) * im.size[1] / im.size[0])
                it = gl.GLImageItem(data)
                it.scale((xb - xa) / im.size[0], hI / im.size[1], 1); it.rotate(90, 1, 0, 0); it.translate(xa, D, 0)
                self.addItem(it)
                if hI < H:
                    self.addItem(_flat(*_quad(xa, xb, D + 0.01, D + 0.01, hI, H, True), (0.05, 0.05, 0.06)))
                done = True
            except Exception:
                done = False
        if T['back'] == 'Modello 3D' and T['backModel']:
            BP = L.backdrop_parts(folder, T)
            yb = max([D] + [float(p['V'][:, 1].max()) for p in BP if len(p['V'])]) + 0.3
            self.addItem(_flat(*_quad(xa, xb, yb, yb, 0, H, True), (0.02, 0.02, 0.025)))    # nero dietro al modello
            for it in mesh_items(BP):
                self.addItem(it)
            done = bool(BP)
        if not done:
            self.addItem(_flat(*_quad(xa, xb, D, D, 0, H, True), bc))
        for e in sh['elements']:
            if e['fixed']:
                its = mesh_items(L.element_parts(folder, e))
                for it in its:
                    self.addItem(it)
                Obj3D(its, e['rot']).place(e['x'], e['y'], 1)
        for o in sc['objects']:
            self.objs.append(self._make(sh, folder, sc, o))
        self.cam0 = dict(center=(0, D * 0.42, 1.6), pos=(0, -max(14, 1.5 * W + P), 0.45 * H + 1.8), fov=40)
        self.apply_camera(self.camCur if (keep_camera and self.camCur) else self.cam0)

    def _make(self, sh, folder, sc, o):
        T = sh['theater']
        if o['kind'] == 'char':
            ch = M.find_char(sh, o['ref'])
            if ch is None:
                return Obj3D([])
            P = L.char_parts(sh, folder, ch, M.cast_code(sh, sc, o['ref']))
            its = mesh_items(P)
            for it in its:
                self.addItem(it)
            zt = L.parts_top(P) + 0.15
            lbl = gl.GLTextItem(pos=(0, 0, zt), text=o['label'], color=(255, 255, 255, 255), font=QtGui.QFont('Arial', 8, QtGui.QFont.Bold))
            self.addItem(lbl)
            return Obj3D(its, 0, lbl, zt)
        if o['kind'] == 'el':
            e = M.find_element(sh, o['ref'])
            if e is None:
                return Obj3D([])
            its = mesh_items(L.element_parts(folder, e))
            for it in its:
                self.addItem(it)
            return Obj3D(its, o['rot'])
        g = M.zone_geom(o['zone'], T)
        if g['shape'] == 'circle':
            n = 40; t = np.linspace(0, 2 * np.pi, n, endpoint=False)
            V = np.c_[np.r_[0, g['r'] * np.cos(t)], np.r_[0, g['r'] * np.sin(t)], np.full(n + 1, 0.014)].astype(np.float32)
            F = np.array([[0, i + 1, (i + 1) % n + 1] for i in range(n)], np.int32); base = 0.35
        elif g['shape'] == 'cyc':
            V, F = _quad(-T['W'] / 2 - T['wing'], T['W'] / 2 + T['wing'], 0.1, 0.1, 0, T['H'], True); base = 0.6
        else:
            V, F = _quad(-g['w'] / 2, g['w'] / 2, -g['h'] / 2, g['h'] / 2, 0.012, 0.012); base = 0.26
        it = _flat(V, F, o['rgb'], base, 'additive')
        self.addItem(it)
        return Obj3D([it], 0, None, 0, it, base, o['rgb'])

    def place(self, i, o, dx, dy, a):
        if 0 <= i < len(self.objs):
            self.objs[i].place(o['x'] + dx, o['y'] + dy, a)

    # ------------------------------------------------ telecamera
    def apply_camera(self, c):
        cx, cy, cz = c['center']; px, py, pz = c['pos']
        dx, dy, dz = px - cx, py - cy, pz - cz; dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        self.opts['center'] = Vector(cx, cy, cz); self.opts['fov'] = c.get('fov', 40)
        self.setCameraPosition(distance=dist, elevation=math.degrees(math.asin(dz / dist)), azimuth=math.degrees(math.atan2(dy, dx)))

    def store_camera(self):
        c = self.opts['center']; d = self.opts['distance']; el = math.radians(self.opts['elevation']); az = math.radians(self.opts['azimuth'])
        pos = (c.x() + d * math.cos(el) * math.cos(az), c.y() + d * math.cos(el) * math.sin(az), c.z() + d * math.sin(el))
        self.camCur = dict(center=(c.x(), c.y(), c.z()), pos=pos, fov=self.opts['fov'])

    def zoom(self, f):
        self.opts['distance'] *= f; self.update(); self.store_camera()

    def reset_camera(self):
        self.camCur = None
        if self.cam0:
            self.apply_camera(self.cam0)

    def mouseReleaseEvent(self, ev):
        super().mouseReleaseEvent(ev); self.store_camera()

    def wheelEvent(self, ev):
        super().wheelEvent(ev); self.store_camera()


class Preview3D(gl.GLViewWidget):
    """anteprima di un personaggio o di un elemento"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setBackgroundColor((20, 23, 28)); self.setMinimumSize(260, 300)

    def show_parts(self, P, elev=8, azim=-75):
        for it in list(self.items):
            self.removeItem(it)
        if not P:
            return
        for it in mesh_items(P):
            self.addItem(it)
        V = np.vstack([p['V'] for p in P]); mn = V.min(0); mx = V.max(0); c = (mn + mx) / 2
        size = float(max(mx - mn))
        self.opts['center'] = Vector(float(c[0]), float(c[1]), float(c[2]))
        self.setCameraPosition(distance=size * 2.2 + 0.3, elevation=elev, azimuth=azim)
