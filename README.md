# Soberano Display & Refresh Rate Picker (Rust + GTK4 Layer-Shell)

Native display resolution and refresh rate manager tailored for Hyprland.
- Bound to: Super + M
- Native Rust + GTK4 + gtk4-layer-shell
- Material Design 3 adaptive theming via Matugen
- Live IPC interaction with Hyprland (`hyprctl monitors -j`)
- Real-time dragging with mouse gestures

## Build & Install
```bash
cargo build --release
cp target/release/display-picker-rs ~/.local/bin/
```
