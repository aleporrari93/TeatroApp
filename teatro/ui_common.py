"""Stile e piccoli componenti condivisi dalle finestre."""
from PySide6 import QtCore, QtGui, QtWidgets

BG = '#14171c'; PANEL = '#21252b'; GOLD = '#d4b05a'; TXT = '#f2ede3'; DIM = '#b3aa9e'; HINT = '#ffd873'

STYLE = """
QWidget { background: %(BG)s; color: %(TXT)s; font-size: 10pt; }
QListWidget, QPlainTextEdit, QTextEdit, QTableWidget, QLineEdit, QComboBox, QDoubleSpinBox, QSpinBox {
    background: %(PANEL)s; color: %(TXT)s; border: 1px solid #3a3f47; border-radius: 3px; }
QListWidget::item:selected, QTableWidget::item:selected { background: #6b5626; color: white; }
QPushButton { background: #2d323a; border: 1px solid #4a505a; border-radius: 4px; padding: 5px 10px; }
QPushButton:hover { background: #3a414b; }
QPushButton:pressed { background: #57492a; }
QPushButton[accent="true"] { background: #6b5626; font-weight: bold; }
QTabWidget::pane { border: 1px solid #3a3f47; }
QTabBar::tab { background: #2d323a; padding: 6px 16px; }
QTabBar::tab:selected { background: #6b5626; }
QHeaderView::section { background: #2d323a; color: %(TXT)s; padding: 3px; border: 0; }
QCheckBox { spacing: 6px; }
QLabel[title="true"] { color: %(GOLD)s; font-size: 18pt; font-weight: bold; }
QLabel[head="true"] { color: %(GOLD)s; font-weight: bold; }
QLabel[dim="true"] { color: %(DIM)s; font-size: 9pt; }
QLabel[hint="true"] { color: %(HINT)s; font-size: 10.5pt; }
""" % dict(BG=BG, PANEL=PANEL, GOLD=GOLD, TXT=TXT, DIM=DIM, HINT=HINT)


def qcol(rgb, a=1.0):
    return QtGui.QColor.fromRgbF(float(rgb[0]), float(rgb[1]), float(rgb[2]), float(a))


def label(text, kind=None, wrap=False):
    w = QtWidgets.QLabel(text)
    if kind:
        w.setProperty(kind, True)
    w.setWordWrap(wrap)
    return w


def button(text, cb=None, accent=False, tip=None):
    b = QtWidgets.QPushButton(text)
    if accent:
        b.setProperty('accent', True)
    if cb:
        b.clicked.connect(lambda *_: cb())
    if tip:
        b.setToolTip(tip)
    return b


class ColorButton(QtWidgets.QPushButton):
    """quadratino colorato: clic = scegli il colore"""
    changed = QtCore.Signal(list)

    def __init__(self, rgb=(0.5, 0.5, 0.5), title='Colore'):
        super().__init__()
        self.setFixedSize(30, 24); self.title = title; self.set_rgb(rgb)
        self.clicked.connect(self._pick)

    def set_rgb(self, rgb):
        self.rgb = [float(c) for c in rgb]
        c = qcol(self.rgb)
        self.setStyleSheet('background: %s; border: 1px solid #888; border-radius: 3px;' % c.name())

    def _pick(self):
        c = QtWidgets.QColorDialog.getColor(qcol(self.rgb), self, self.title)
        if c.isValid():
            self.set_rgb([c.redF(), c.greenF(), c.blueF()]); self.changed.emit(self.rgb)


def ask_text(parent, title, fields, defaults=None):
    """finestra con piu' campi di testo; ritorna la lista dei valori o None"""
    d = QtWidgets.QDialog(parent); d.setWindowTitle(title); lay = QtWidgets.QFormLayout(d)
    eds = []
    for i, f in enumerate(fields):
        e = QtWidgets.QLineEdit(str(defaults[i]) if defaults else ''); e.setMinimumWidth(380); lay.addRow(f, e); eds.append(e)
    bb = QtWidgets.QDialogButtonBox(QtWidgets.QDialogButtonBox.Ok | QtWidgets.QDialogButtonBox.Cancel)
    bb.accepted.connect(d.accept); bb.rejected.connect(d.reject); lay.addRow(bb)
    if d.exec() != QtWidgets.QDialog.Accepted:
        return None
    return [e.text().strip() for e in eds]


def confirm(parent, text, title='Conferma', yes='Si'):
    r = QtWidgets.QMessageBox.question(parent, title, text, QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No, QtWidgets.QMessageBox.No)
    return r == QtWidgets.QMessageBox.Yes


def info(parent, text, title='Teatro'):
    QtWidgets.QMessageBox.information(parent, title, text)


def error(parent, text, title='Teatro'):
    QtWidgets.QMessageBox.critical(parent, title, text)


def open_folder(path):
    QtGui.QDesktopServices.openUrl(QtCore.QUrl.fromLocalFile(path))


def num(text, default):
    try:
        return float(str(text).replace(',', '.'))
    except ValueError:
        return default
