#!/usr/bin/env bash
# Bước 5: Đăng ký Hyprland session với login manager.
#
# Tạo .desktop file cho GDM/LightDM/SDDM để login screen có lựa chọn Hyprland.
# GNOME giữ nguyên — Hyprland dở chứng thì login về GNOME vẫn có desktop chạy việc.

set -euo pipefail

PREFIX=/opt/hypr
HYPRLAND_BIN="${PREFIX}/bin/Hyprland"
SESSION_DIR=/usr/share/wayland-sessions

die() { echo "[ERROR] $*" >&2; exit 1; }

# Kiểm tra binary đã build chưa
if [[ ! -f "${HYPRLAND_BIN}" ]]; then
    die "Không tìm thấy ${HYPRLAND_BIN}. Chạy 02-build-stack.sh trước."
fi

echo "[04-session] Tạo thư mục Wayland sessions..."
sudo mkdir -p "${SESSION_DIR}"

echo "[04-session] Ghi file session descriptor..."
cat <<EOF | sudo tee "${SESSION_DIR}/hyprland.desktop" > /dev/null
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=${HYPRLAND_BIN}
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EOF
echo "[04-session] Đã tạo: ${SESSION_DIR}/hyprland.desktop"

echo "[04-session] Tạo wrapper script để set env trước khi launch..."
cat <<EOF | sudo tee "${PREFIX}/bin/start-hyprland" > /dev/null
#!/usr/bin/env bash
# Wrapper cho Hyprland — set đúng env cho NVIDIA trước khi launch.

export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_CURRENT_DESKTOP=Hyprland

# Cần cho aquamarine + NVIDIA DRM
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia

# Đảm bảo /opt/hypr libs được tìm thấy
export LD_LIBRARY_PATH="${PREFIX}/lib:\${LD_LIBRARY_PATH:-}"

exec "${HYPRLAND_BIN}" "\$@"
EOF
sudo chmod +x "${PREFIX}/bin/start-hyprland"
echo "[04-session] Đã tạo wrapper: ${PREFIX}/bin/start-hyprland"

echo "[04-session] Cập nhật session để dùng wrapper..."
cat <<EOF | sudo tee "${SESSION_DIR}/hyprland.desktop" > /dev/null
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=${PREFIX}/bin/start-hyprland
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EOF

echo "[04-session] Cài xdg-desktop-portal-hyprland nếu có..."
# Portal backend cho Wayland (screen sharing, file picker)
if apt-cache show xdg-desktop-portal-hyprland &>/dev/null; then
    sudo apt-get install -y xdg-desktop-portal-hyprland
else
    echo "[04-session] xdg-desktop-portal-hyprland không có trong apt."
    echo "             Cần build từ source hoặc dùng xdg-desktop-portal-wlr."
    if apt-cache show xdg-desktop-portal-wlr &>/dev/null; then
        sudo apt-get install -y xdg-desktop-portal-wlr
        echo "[04-session] Đã cài xdg-desktop-portal-wlr thay thế."
    fi
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  SESSION REGISTRATION HOÀN THÀNH        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Login screen của GDM sẽ có lựa chọn 'Hyprland' ở góc phải dưới."
echo "GNOME vẫn còn — chọn 'GNOME' để quay về nếu cần."
echo ""
echo "Để test không cần reboot (từ TTY):"
echo "  Ctrl+Alt+F2 → login → export DISPLAY=:0 → ${PREFIX}/bin/start-hyprland"
