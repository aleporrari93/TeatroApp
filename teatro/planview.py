"""Pianta del palco (vista dall'alto) disegnata con QPainter. Coordinate in metri: X = 0 al centro,
Y = 0 sul boccascena, Y cresce verso il fondale; il pubblico e' in basso."""
import math
import os

from PySide6 import QtCore, QtGui, QtWidgets

from . import model as M
from .ui_common import BG, qcol


class PlanView(QtWidgets.QWidget):
    pressed = QtCore.Signal(float, float, int)
    moved = QtCore.Signal(float, float)
    released = QtCore.Signal(float, float)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.sh = None; self.folder = ''; self.items = []; self.paths = []; self.temp_path = []; self.start_mark = None
        self.title = ''; self.show_size = False; self._img = None; self._img_key = None
        self.setMinimumSize(420, 320); self.setMouseTracking(True)

    def set_context(self, sh, folder):
        self.sh = sh; self.folder = folder; self.update()

    def set_items(self, items):
        """items: lista di (oggetto, dx, dy, alpha)"""
        self.items = items; self.update()

    # ------------------------------------------------ trasformazione mondo <-> schermo
    def _frame(self):
        T = self.sh['theater']; xa = -T['W'] / 2 - T['wing'] - 0.4; xb = -xa
        ya = -T['P'] - 1.0; yb = T['D'] + 0.7
        top = 22 if self.title else 4
        w = self.width() - 8; h = self.height() - top - 4
        s = min(w / (xb - xa), h / (yb - ya))
        ox = 4 + (w - s * (xb - xa)) / 2; oy = top + (h - s * (yb - ya)) / 2
        return xa, ya, yb, s, ox, oy

    def w2s(self, x, y):
        xa, ya, yb, s, ox, oy = self._frame()
        return QtCore.QPointF(ox + (x - xa) * s, oy + (yb - y) * s)

    def s2w(self, px, py):
        xa, ya, yb, s, ox, oy = self._frame()
        return xa + (px - ox) / s, yb - (py - oy) / s

    def scale(self):
        return self._frame()[3]

    # ------------------------------------------------ mouse
    def _inside(self, x, y):
        T = self.sh['theater']
        return abs(x) <= T['W'] / 2 + T['wing'] + 0.4 and -T['P'] - 1.0 <= y <= T['D'] + 0.7

    def mousePressEvent(self, ev):
        if not self.sh:
            return
        x, y = self.s2w(ev.position().x(), ev.position().y())
        if self._inside(x, y):
            self.pressed.emit(x, y, 1 if ev.button() == QtCore.Qt.LeftButton else 2)

    def mouseMoveEvent(self, ev):
        if not self.sh:
            return
        x, y = self.s2w(ev.position().x(), ev.position().y())
        if self._inside(x, y):
            self.moved.emit(x, y)

    def mouseReleaseEvent(self, ev):
        if not self.sh:
            return
        x, y = self.s2w(ev.position().x(), ev.position().y())
        self.released.emit(x, y)

    # ------------------------------------------------ disegno
    def _poly(self, pts):
        return QtGui.QPolygonF([self.w2s(x, y) for x, y in pts])

    def _backdrop_image(self):
        T = self.sh['theater']
        if T['back'] != 'Immagine (foto o disegno)' or not T['backImg']:
            return None
        key = (self.folder, T['backImg'])
        if key != self._img_key:
            p = os.path.join(self.folder, 'fondale', T['backImg'])
            self._img = QtGui.QImage(p) if os.path.exists(p) else None; self._img_key = key
        return self._img

    def paintEvent(self, ev):
        p = QtGui.QPainter(self); p.setRenderHint(QtGui.QPainter.Antialiasing)
        p.fillRect(self.rect(), QtGui.QColor(BG))
        if not self.sh:
            return
        T = self.sh['theater']; W, D, P, wg = T['W'], T['D'], T['P'], T['wing']
        xa, xb = -W / 2 - wg, W / 2 + wg
        s = self.scale()
        if self.title:
            p.setPen(QtGui.QColor('#d4b05a')); f = p.font(); f.setBold(True); p.setFont(f)
            p.drawText(QtCore.QRectF(0, 2, self.width(), 18), QtCore.Qt.AlignCenter, self.title)
            f.setBold(False); p.setFont(f)
        p.setPen(QtCore.Qt.NoPen)
        p.setBrush(QtGui.QColor('#1f1f24')); p.drawPolygon(self._poly([(xa, 0), (xb, 0), (xb, D), (xa, D)]))
        p.setBrush(QtGui.QColor('#573f30')); p.drawPolygon(self._poly([(-W / 2, 0), (W / 2, 0), (W / 2, D), (-W / 2, D)]))
        p.setBrush(QtGui.QColor('#664f38')); p.drawPolygon(self._poly([(xa, -P), (xb, -P), (xb, 0), (xa, 0)]))
        p.setPen(QtGui.QPen(QtGui.QColor('#4d3b2b'), 1))
        for yy in range(0, int(D) + 1):
            p.drawLine(self.w2s(-W / 2, yy), self.w2s(W / 2, yy))
        for xx in range(math.ceil(-W / 2), math.floor(W / 2) + 1):
            p.drawLine(self.w2s(xx, 0), self.w2s(xx, D))
        qw = M.quinte_width(T)
        p.setPen(QtGui.QPen(QtGui.QColor('#000000'), max(3, 0.12 * s)))
        for yy in M.quinte_y(T):
            for sd in (-1, 1):
                p.drawLine(self.w2s(sd * (W / 2 - 0.2), yy), self.w2s(sd * (W / 2 - 0.2 + qw), yy))
        p.setPen(QtGui.QPen(QtGui.QColor('#0c0c0c'), max(4, 0.16 * s))); p.drawLine(self.w2s(xa, D), self.w2s(xb, D))
        p.setPen(QtGui.QPen(QtGui.QColor('#c03333'), 1, QtCore.Qt.DashLine)); p.drawLine(self.w2s(xa, 0), self.w2s(xb, 0))
        img = self._backdrop_image()
        if img is not None and not img.isNull():
            r = QtCore.QRectF(self.w2s(xa, D + 0.6), self.w2s(xb, D + 0.08)); p.drawImage(r, img)
        tc = QtGui.QColor('#bfb8a8'); p.setPen(tc)
        f = p.font(); f.setPointSizeF(8); p.setFont(f)
        c = self.w2s(0, -P - 0.55); p.drawText(QtCore.QRectF(c.x() - 80, c.y() - 10, 160, 20), QtCore.Qt.AlignCenter, 'PUBBLICO')
        if img is None:
            c = self.w2s(0, D + 0.35); p.drawText(QtCore.QRectF(c.x() - 80, c.y() - 10, 160, 20), QtCore.Qt.AlignCenter, 'FONDALE')
        for sd, t in ((-1, 'QUINTE SX'), (1, 'QUINTE DX')):
            c = self.w2s(sd * (W / 2 + wg - 0.15), D / 2)
            p.save(); p.translate(c); p.rotate(-90 * sd); p.drawText(QtCore.QRectF(-60, -8, 120, 16), QtCore.Qt.AlignCenter, t); p.restore()
        if self.show_size:
            p.setPen(QtGui.QColor('white')); f.setPointSizeF(12); p.setFont(f)
            c = self.w2s(0, D / 2); p.drawText(QtCore.QRectF(c.x() - 100, c.y() - 12, 200, 24), QtCore.Qt.AlignCenter, '%g x %g m' % (W, D))
        f.setPointSizeF(8); p.setFont(f)
        # elementi fissi
        for e in self.sh['elements']:
            if e['fixed']:
                o = M.new_obj(0, 'el', e['name'], e['name'], e['x'], e['y'], M.plan_color(e), '', e['size'][0], e['size'][1], e['rot'], True)
                self._draw_obj(p, o, 0, 0, 1, dashed=True)
        order = {'light': 0, 'el': 1, 'char': 2}
        for o, dx, dy, a in sorted(self.items, key=lambda it: order.get(it[0]['kind'], 1)):
            if a > 0.02:
                self._draw_obj(p, o, dx, dy, a)
        for pts, rgb in self.paths:
            if len(pts) > 1:
                p.setPen(QtGui.QPen(qcol(rgb), 2)); p.setBrush(QtCore.Qt.NoBrush); p.drawPolyline(self._poly(pts))
                q = self.w2s(*pts[-1]); p.setPen(QtGui.QPen(QtGui.QColor('white'), 1)); p.setBrush(qcol(rgb))
                p.drawRect(QtCore.QRectF(q.x() - 4, q.y() - 4, 8, 8))
        if len(self.temp_path) > 1:
            p.setPen(QtGui.QPen(QtGui.QColor('#ffd94d'), 3)); p.setBrush(QtCore.Qt.NoBrush); p.drawPolyline(self._poly(self.temp_path))
        if self.start_mark is not None:
            q = self.w2s(*self.start_mark); p.setPen(QtGui.QPen(QtGui.QColor('#ffd94d'), 2)); p.setBrush(QtCore.Qt.NoBrush)
            p.drawEllipse(q, 12, 12)
        p.end()

    def _draw_obj(self, p, o, dx, dy, a, dashed=False):
        x, y = o['x'] + dx, o['y'] + dy; s = self.scale()
        if o['kind'] == 'char':
            c = self.w2s(x, y); r = 0.3 * s
            p.setPen(QtGui.QPen(QtGui.QColor('white'), 1.5)); col = qcol(o['rgb']); col.setAlphaF(min(1, a)); p.setBrush(col)
            p.drawEllipse(c, r, r)
            p.setPen(QtGui.QColor('black') if sum(o['rgb']) / 3 > 0.6 else QtGui.QColor('white'))
            f = p.font(); f.setBold(True); f.setPointSizeF(max(6, min(9, r * 0.6))); p.setFont(f)
            p.drawText(QtCore.QRectF(c.x() - r, c.y() - r, 2 * r, 2 * r), QtCore.Qt.AlignCenter, M.initials(o['label']))
            f.setBold(False); f.setPointSizeF(8); p.setFont(f); p.setPen(QtGui.QColor('white'))
            p.drawText(QtCore.QRectF(c.x() - 70, c.y() + r + 1, 140, 14), QtCore.Qt.AlignCenter, o['label'])
        elif o['kind'] == 'el':
            w, d = max(o['w'], 0.1), max(o['d'], 0.1); t = math.radians(o['rot']); ct, st = math.cos(t), math.sin(t)
            pts = [(x + ct * u - st * v, y + st * u + ct * v) for u, v in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
            fill = qcol([0.5 + 0.5 * c for c in o['rgb']], 0.85 * min(1, a))
            pen = QtGui.QPen(qcol([0.6 * c for c in o['rgb']]), 1.2, QtCore.Qt.DashLine if dashed else QtCore.Qt.SolidLine)
            p.setPen(pen); p.setBrush(fill); p.drawPolygon(self._poly(pts))
            c = self.w2s(x, y); p.setPen(QtGui.QColor('#1a1a1a'))
            f = p.font(); f.setPointSizeF(7); p.setFont(f)
            p.drawText(QtCore.QRectF(c.x() - 80, c.y() - 8, 160, 16), QtCore.Qt.AlignCenter, o['label'])
        else:
            _, g, x, y = M.light_place(self.sh, o, dx, dy)
            col = qcol(o['rgb'], (0.7 if g['shape'] == 'cyc' else 0.22) * min(1, a))
            p.setPen(QtCore.Qt.NoPen); p.setBrush(col)
            if g['shape'] == 'circle':
                c = self.w2s(x, y); p.drawEllipse(c, g['r'] * s, g['r'] * s)
            elif g['shape'] == 'cyc':
                p.drawPolygon(self._poly([(x - g['w'] / 2, y - 0.15), (x + g['w'] / 2, y - 0.15), (x + g['w'] / 2, y + 0.15), (x - g['w'] / 2, y + 0.15)]))
            else:
                p.drawPolygon(self._poly([(x - g['w'] / 2, y - g['h'] / 2), (x + g['w'] / 2, y - g['h'] / 2),
                                          (x + g['w'] / 2, y + g['h'] / 2), (x - g['w'] / 2, y + g['h'] / 2)]))
