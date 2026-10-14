#!/usr/bin/env python3
"""
HyprKeybindsCheatSheet.py - Modern Glass Floating HUD Cheat-Sheet for JaKooLit + Noctalia
Bound to: Super + Shift + ? / Super + H
"""
import sys
import os
import signal
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QLineEdit, QScrollArea, QFrame, QPushButton, QGridLayout
)
from PyQt6.QtCore import Qt, QPoint
from PyQt6.QtGui import QFont, QColor

PID_FILE = "/tmp/hypr_keybinds_cheatsheet.pid"

SHORTCUT_DATA = [
    {
        "category": "󰏘 Personalização & Rice",
        "color": "#cba6f7",
        "items": [
            ("Super + Alt + B", "Estilos de Barra", "Alterna entre 13 temas (Cyberpunk, Glass, Catppuccin, Dracula...)"),
            ("Super + Ctrl + B", "Layouts de Barra", "Alterna entre 6 geometrias (Ilhas, Dock Inferior, Barra Dupla...)"),
            ("Super + Alt + A", "Perfis de Animação", "Alterna física de janelas (Fast, Smooth, Bouncy Spring, Instant Zero)"),
            ("Super + W", "Seletor de Wallpapers", "Abre o menu visual de papéis de parede"),
            ("Super + Alt + W", "Wallpaper Aleatório", "Aplica um papel de parede aleatório com sincronização"),
            ("Super + Alt + R", "Recarregar Interface", "Reaplica templates de cores no Kitty, GTK e barra"),
        ]
    },
    {
        "category": "󰖲 Gestão de Janelas",
        "color": "#89b4fa",
        "items": [
            ("Super + Q", "Fechar Janela", "Fecha a janela atualmente em foco"),
            ("Super + Espaço", "Alternar Flutuante", "Alterna janela entre modo tiling e flutuante"),
            ("Super + F", "Tela Cheia Total", "Coloca a janela em fullscreen exclusivo"),
            ("Super + Shift + F", "Tela Cheia Monocle", "Expande a janela mantendo a barra de status visível"),
            ("Super + J", "Alternar Divisão", "Alterna direção de corte do tiling (horizontal/vertical)"),
            ("Alt + Tab", "Ciclar Janelas", "Alterna o foco para a próxima janela aberta"),
            ("Super + Tab", "Alternador Visual", "Abre o visual switcher de janelas em overlay"),
            ("Super + Setas", "Navegar Foco", "Muda o foco da janela na direção das setas"),
            ("Super + Shift + Setas", "Mover Janela", "Move a janela ativa dentro do layout de tela"),
        ]
    },
    {
        "category": "󰍹 Workspaces & Monitores",
        "color": "#a6e3a1",
        "items": [
            ("Super + 1 .. 9, 0", "Ir para Workspace", "Foca instantaneamente na área de trabalho 1 a 10"),
            ("Super + Shift + 1 .. 9, 0", "Mover para Workspace", "Move a janela ativa para a área de trabalho 1 a 10"),
            ("Super + Shift + Alt + 1..0", "Mover Silencioso", "Envia a janela para a workspace sem segui-la"),
            ("Super + Ctrl + 1 .. 3", "Focar Monitor", "Muda o foco para o monitor correspondente (1, 2 ou 3)"),
            ("Super + Ctrl + Shift + 1..3", "Mover para Monitor", "Move a janela ativa para o monitor selecionado"),
            ("Super + S", "Scratchpad Especial", "Alterna a exibição da área de notas/janelas especiais"),
            ("Super + Shift + S", "Enviar p/ Scratchpad", "Envia a janela atual para o scratchpad especial"),
            ("Super + Scroll Mouse", "Rolar Workspaces", "Percorre as áreas de trabalho com a roda do mouse"),
        ]
    },
    {
        "category": "󰈸 Utilitários & Sistema",
        "color": "#fab387",
        "items": [
            ("Super + Espaço / D", "Lançador de Apps", "Abre o menu de aplicativos"),
            ("Super + V / Alt + V", "Área de Transferência", "Histórico do clipboard com pesquisa rápida"),
            ("Super + A", "Visão Geral (Overview)", "Modo de visão geral das janelas e áreas de trabalho"),
            ("Super + P", "Seletor de Cores", "Captura cor de qualquer pixel da tela para o clipboard"),
            ("Print", "Captura de Região", "Seleciona uma área com o mouse e salva captura"),
            ("Super + Print", "Captura Tela Inteira", "Salva captura de todos os monitores"),
            ("Super + G / F1", "Modo Gamer", "Desativa blur e animações para máximo FPS em jogos"),
            ("Ctrl + Alt + L", "Bloquear Sessão", "Bloqueia a tela imediatamente"),
            ("Ctrl + Alt + Del", "Menu de Desligamento", "Abre o painel de suspensão, reinício e desligamento"),
        ]
    }
]

STYLESHEET = """
QMainWindow {
    background: transparent;
}
#mainContainer {
    background-color: rgba(18, 20, 28, 0.94);
    border: 1.5px solid #00f0ff;
    border-radius: 20px;
}
#headerTitle {
    color: #ffffff;
    font-size: 20px;
    font-weight: bold;
}
#headerSubtitle {
    color: #89b4fa;
    font-size: 13px;
}
#searchBox {
    background-color: rgba(30, 34, 48, 0.85);
    border: 1px solid #45475a;
    border-radius: 10px;
    padding: 8px 14px;
    color: #ffffff;
    font-size: 14px;
}
#searchBox:focus {
    border: 1.5px solid #00f0ff;
}
#closeBtn {
    background-color: rgba(243, 139, 168, 0.2);
    border: 1px solid #f38ba8;
    color: #f38ba8;
    border-radius: 8px;
    padding: 4px 12px;
    font-weight: bold;
}
#closeBtn:hover {
    background-color: #f38ba8;
    color: #11111b;
}
QScrollArea {
    background: transparent;
    border: none;
}
QScrollBar:vertical {
    border: none;
    background: rgba(30, 34, 48, 0.4);
    width: 8px;
    border-radius: 4px;
}
QScrollBar::handle:vertical {
    background: #45475a;
    border-radius: 4px;
    min-height: 20px;
}
QScrollBar::handle:vertical:hover {
    background: #00f0ff;
}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
    height: 0px;
}
.categoryBox {
    background-color: rgba(26, 29, 41, 0.7);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
    padding: 12px;
}
.keycap {
    background-color: rgba(49, 50, 68, 0.9);
    border: 1px solid #585b70;
    border-radius: 6px;
    padding: 3px 8px;
    color: #00f0ff;
    font-weight: bold;
    font-family: monospace;
    font-size: 12px;
}
.itemTitle {
    color: #ffffff;
    font-size: 13px;
    font-weight: bold;
}
.itemDesc {
    color: #a6adc8;
    font-size: 11px;
}
"""

class KeybindRow(QWidget):
    def __init__(self, key, title, desc, parent=None):
        super().__init__(parent)
        self.key_text = key.lower()
        self.title_text = title.lower()
        self.desc_text = desc.lower()

        layout = QHBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(10)

        # Keycap Label
        lbl_key = QLabel(key)
        lbl_key.setProperty("class", "keycap")
        lbl_key.setStyleSheet("background-color: rgba(40, 44, 60, 0.95); border: 1px solid #45475a; border-radius: 6px; padding: 4px 8px; color: #00f0ff; font-weight: bold; font-family: monospace; font-size: 12px;")
        lbl_key.setFixedWidth(220)
        lbl_key.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(lbl_key)

        # Title & Description
        info_layout = QVBoxLayout()
        info_layout.setContentsMargins(0, 0, 0, 0)
        info_layout.setSpacing(2)

        lbl_title = QLabel(title)
        lbl_title.setStyleSheet("color: #ffffff; font-weight: bold; font-size: 13px;")
        info_layout.addWidget(lbl_title)

        lbl_desc = QLabel(desc)
        lbl_desc.setStyleSheet("color: #a6adc8; font-size: 11px;")
        info_layout.addWidget(lbl_desc)

        layout.addLayout(info_layout)
        layout.addStretch()

    def matches(self, query):
        if not query:
            return True
        return query in self.key_text or query in self.title_text or query in self.desc_text

class CheatSheetWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Atalhos do Sistema")
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.resize(960, 680)

        self.rows = []
        self.category_widgets = []

        self.init_ui()

    def init_ui(self):
        central = QWidget()
        central.setObjectName("mainContainer")
        self.setCentralWidget(central)

        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(24, 20, 24, 20)
        main_layout.setSpacing(16)

        # --- Header ---
        header = QHBoxLayout()
        header_text = QVBoxLayout()
        header_text.setSpacing(2)

        title = QLabel("󰌌 Atalhos do Sistema — JaKooLit + Noctalia")
        title.setObjectName("headerTitle")
        header_text.addWidget(title)

        subtitle = QLabel("Guia Rápido de Produtividade • Pressione ESC para fechar")
        subtitle.setObjectName("headerSubtitle")
        header_text.addWidget(subtitle)
        header.addLayout(header_text)

        header.addStretch()

        close_btn = QPushButton("✕ Fechar")
        close_btn.setObjectName("closeBtn")
        close_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        close_btn.clicked.connect(self.close)
        header.addWidget(close_btn)
        main_layout.addLayout(header)

        # --- Search Box ---
        self.search_input = QLineEdit()
        self.search_input.setObjectName("searchBox")
        self.search_input.setPlaceholderText("🔍 Digite para filtrar atalhos (ex: tela cheia, barra, workspace, print)...")
        self.search_input.textChanged.connect(self.filter_keybinds)
        main_layout.addWidget(self.search_input)

        # --- Scroll Area with Categories ---
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll_content = QWidget()
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setContentsMargins(0, 0, 10, 0)
        scroll_layout.setSpacing(14)

        for cat in SHORTCUT_DATA:
            cat_frame = QFrame()
            cat_frame.setStyleSheet(f"background-color: rgba(24, 27, 38, 0.85); border: 1px solid rgba(255, 255, 255, 0.08); border-left: 3px solid {cat['color']}; border-radius: 12px; padding: 10px;")
            cat_layout = QVBoxLayout(cat_frame)
            cat_layout.setContentsMargins(8, 8, 8, 8)
            cat_layout.setSpacing(8)

            cat_title = QLabel(cat["category"])
            cat_title.setStyleSheet(f"color: {cat['color']}; font-size: 14px; font-weight: bold;")
            cat_layout.addWidget(cat_title)

            cat_rows = []
            for k, t, d in cat["items"]:
                row = KeybindRow(k, t, d)
                cat_layout.addWidget(row)
                self.rows.append(row)
                cat_rows.append(row)

            scroll_layout.addWidget(cat_frame)
            self.category_widgets.append((cat_frame, cat_rows))

        scroll.setWidget(scroll_content)
        main_layout.addWidget(scroll)

        # Center on screen
        screen = QApplication.primaryScreen().geometry()
        x = (screen.width() - self.width()) // 2
        y = (screen.height() - self.height()) // 2
        self.move(x, y)

    def filter_keybinds(self, text):
        query = text.strip().lower()
        for cat_frame, cat_rows in self.category_widgets:
            visible_count = 0
            for r in cat_rows:
                is_match = r.matches(query)
                r.setVisible(is_match)
                if is_match:
                    visible_count += 1
            cat_frame.setVisible(visible_count > 0)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Escape:
            self.close()
        else:
            super().keyPressEvent(event)

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

if __name__ == "__main__":
    check_singleton()
    app = QApplication(sys.argv)
    app.setApplicationName("hypr-keybinds-cheat-sheet")
    app.setStyleSheet(STYLESHEET)
    app.aboutToQuit.connect(cleanup)

    win = CheatSheetWindow()
    win.show()
    sys.exit(app.exec())
