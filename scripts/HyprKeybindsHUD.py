#!/usr/bin/env python3
"""
HyprKeybindsHUD.py - Ultra-fast, High-Fidelity HUD for Keybindings.
Powered by PyQt6 + Chromium on Wayland with zero protocol errors and rock-solid rendering.
"""
import sys
import os
import signal
from PyQt6 import QtWidgets, QtCore, QtGui
from PyQt6.QtWebEngineWidgets import QWebEngineView

# Sync theme with system and Noctalia style
try:
    import hud_theme_sync
    hud_theme_sync.sync_all()
except Exception as e:
    pass

PID_FILE = "/tmp/hypr_keybinds_hud.pid"
HTML_PATH = os.path.expanduser("~/dotfiles/config/hypr/hud/index.html")

def check_singleton():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGTERM)
            os.remove(PID_FILE)
            sys.exit(0)
        except (ProcessLookupError, ValueError):
            pass
        except Exception:
            pass

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

def cleanup():
    if os.path.exists(PID_FILE):
        try:
            os.remove(PID_FILE)
        except Exception:
            pass

class KeybindsHUDWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Atalhos do Sistema")
        self.setWindowFlags(QtCore.Qt.WindowType.FramelessWindowHint | QtCore.Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.resize(1100, 800)

        # Center on active monitor
        screen_geo = QtGui.QGuiApplication.primaryScreen().geometry()
        x = (screen_geo.width() - 1100) // 2
        y = (screen_geo.height() - 800) // 2
        self.move(x, y)

        # WebEngine View
        self.view = QWebEngineView(self)
        self.view.setStyleSheet("background: transparent;")
        self.view.page().setBackgroundColor(QtGui.QColor(0, 0, 0, 0))
        
        # Load index.html
        if os.path.exists(HTML_PATH):
            self.view.setUrl(QtCore.QUrl.fromLocalFile(HTML_PATH))
        else:
            self.view.setHtml("<h1>Erro: index.html não encontrado</h1>")

        # JS window.close() bridge
        self.view.page().windowCloseRequested.connect(self.close_window)

        self.setCentralWidget(self.view)

    def keyPressEvent(self, event: QtGui.QKeyEvent):
        if event.key() == QtCore.Qt.Key.Key_Escape:
            self.close_window()
            event.accept()
        else:
            super().keyPressEvent(event)

    def close_window(self):
        cleanup()
        QtWidgets.QApplication.quit()

    def closeEvent(self, event):
        cleanup()
        event.accept()

def main():
    check_singleton()

    # Pass wayland app-id
    os.environ["QT_QPA_PLATFORM"] = "wayland"
    
    app = QtWidgets.QApplication(sys.argv)
    app.setApplicationName("hypr-keybinds-hud")
    app.setDesktopFileName("hypr-keybinds-hud")

    win = KeybindsHUDWindow()
    win.show()

    signal.signal(signal.SIGINT, lambda *_: win.close_window())
    signal.signal(signal.SIGTERM, lambda *_: win.close_window())

    ret = app.exec()
    cleanup()
    sys.exit(ret)

if __name__ == "__main__":
    main()
