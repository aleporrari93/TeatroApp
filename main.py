"""TeatroApp - regia di spettacoli teatrali. Avvio:  python main.py"""
import sys
import traceback

from PySide6 import QtCore, QtGui, QtWidgets


def main():
    QtCore.QCoreApplication.setAttribute(QtCore.Qt.AA_ShareOpenGLContexts)
    app = QtWidgets.QApplication(sys.argv)
    app.setApplicationName('TeatroApp')
    from teatro.ui_common import STYLE, error, install_screen_guard
    app.setStyleSheet(STYLE)
    install_screen_guard(app)

    def excepthook(t, v, tb):
        msg = ''.join(traceback.format_exception(t, v, tb))
        sys.stderr.write(msg)
        try:
            error(None, 'Si e\' verificato un errore:\n\n' + msg[-1500:], 'TeatroApp')
        except Exception:
            pass
    sys.excepthook = excepthook
    from teatro.home import App, HomeWindow
    state = App()
    w = HomeWindow(state); w.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
