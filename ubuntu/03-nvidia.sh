#!/usr/bin/env bash
# Bước 4: Cấu hình NVIDIA RTX 3070 cho Hyprland (aquamarine backend).
#
# LƯU Ý QUAN TRỌNG:
# WLR_NO_HARDWARE_CURSORS là biến cũ của wlroots — KHÔNG dùng được với
# Hyprland mới (aquamarine backend). Thay vào đó dùng cursor.no_hardware_cursors
# trong hyprland.conf và các env vars NVIDIA bên dưới.
#
# Yêu cầu: driver NVIDIA >= 525 (driver 595 của mày là ổn).

set -euo pipefail

die() { echo "[ERROR] $*" >&2; exit 1; }

# Kiểm tra driver NVIDIA
if ! lsmod | grep -q nvidia; then
    echo "[WARN] Module nvidia chưa load. Đảm bảo driver đã cài trước khi chạy script này."
fi

echo "[03-nvidia] ── Bước 1: Bật nvidia-drm.modeset=1 ─────────────────────"
# modeset=1 bắt buộc cho DRM/KMS — Hyprland KHÔNG chạy được nếu thiếu cái này.
MODPROBE_CONF=/etc/modprobe.d/nvidia-hyprland.conf
cat <<'EOF' | sudo tee "${MODPROBE_CONF}" > /dev/null
# Hyprland/aquamarine cần nvidia-drm.modeset=1 để dùng KMS.
# Không đổi thành 0 — Hyprland sẽ không khởi động được.
options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
echo "[03-nvidia] Đã ghi: ${MODPROBE_CONF}"

echo "[03-nvidia] ── Bước 2: Nhét nvidia modules vào initramfs ─────────────"
INITRAMFS_MODULES=/etc/initramfs-tools/modules
# Thêm các module nếu chưa có
for mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
    if ! grep -qx "$mod" "${INITRAMFS_MODULES}" 2>/dev/null; then
        echo "$mod" | sudo tee -a "${INITRAMFS_MODULES}" > /dev/null
        echo "[03-nvidia] Thêm module: ${mod}"
    else
        echo "[03-nvidia] Module đã có: ${mod}"
    fi
done

echo "[03-nvidia] Chạy update-initramfs..."
sudo update-initramfs -u

echo "[03-nvidia] ── Bước 3: Tạo udev rule cho NVIDIA DRM ─────────────────"
# Đảm bảo /dev/dri/card* có đúng permission
cat <<'EOF' | sudo tee /etc/udev/rules.d/99-nvidia-drm.rules > /dev/null
# Hyprland: NVIDIA DRM device permissions
KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="nvidia", GROUP="video", MODE="0660"
KERNEL=="renderD*", SUBSYSTEM=="drm", GROUP="render", MODE="0660"
EOF

# Đảm bảo user thuộc group video và render
CURRENT_USER="${SUDO_USER:-$USER}"
for grp in video render input; do
    if ! groups "${CURRENT_USER}" | grep -qw "$grp"; then
        echo "[03-nvidia] Thêm ${CURRENT_USER} vào group ${grp}..."
        sudo usermod -aG "$grp" "${CURRENT_USER}"
    fi
done

echo "[03-nvidia] ── Bước 4: Tạo environment file cho Hyprland session ─────"
HYPR_ENV_DIR="${HOME}/.config/hypr"
mkdir -p "${HYPR_ENV_DIR}"

cat <<'EOF' > "${HYPR_ENV_DIR}/nvidia-env.conf"
# NVIDIA RTX 3070 — Hyprland environment vars
# Import file này vào hyprland.conf bằng: source = ~/.config/hypr/nvidia-env.conf

# Dùng NVIDIA cho VA-API hardware decode
env = LIBVA_DRIVER_NAME,nvidia

# Ép GLX dùng NVIDIA vendor library thay vì Mesa fallback
env = __GLX_VENDOR_LIBRARY_NAME,nvidia

# GBM backend (aquamarine cần cái này với NVIDIA)
env = GBM_BACKEND,nvidia-drm

# Electron/Chromium apps chạy tốt hơn trên Wayland
env = NIXOS_OZONE_WL,1
env = ELECTRON_OZONE_PLATFORM_HINT,auto

# XWayland scale fix
env = XWAYLAND_NO_GLAMOR,1
EOF
echo "[03-nvidia] Đã tạo: ${HYPR_ENV_DIR}/nvidia-env.conf"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  NVIDIA SETUP HOÀN THÀNH                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "CẦN REBOOT để modprobe + initramfs có hiệu lực."
echo ""
echo "Sau khi reboot, kiểm tra bằng:"
echo "  cat /sys/module/nvidia_drm/parameters/modeset   # phải ra 'Y'"
echo "  ls /dev/dri/                                    # phải thấy card0, renderD128"
echo ""
echo "Nhớ thêm vào hyprland.conf:"
echo "  source = ~/.config/hypr/nvidia-env.conf"
echo "  cursor {"
echo "      no_hardware_cursors = true   # bật nếu con trỏ nhấp nháy"
echo "  }"
