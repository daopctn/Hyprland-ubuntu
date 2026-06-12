#!/usr/bin/env bash
# Master runner — chạy toàn bộ pipeline từ đầu đến cuối.
#
# Dùng cái này nếu mày muốn chạy tất cả một lần.
# Hoặc chạy từng bước riêng nếu muốn kiểm soát từng bước.
#
# Thứ tự: 00 → 01 → 02 → 03 → 04 → 05
# Sau đó: reboot → chọn Hyprland ở GDM.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "[ERROR] $*" >&2; exit 1; }

step() {
    local num="$1" name="$2" script="$3"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  BƯỚC ${num}: ${name}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "${SCRIPT_DIR}/${script}" || die "Bước ${num} thất bại: ${script}"
}

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  HYPRLAND BUILD PIPELINE — Ubuntu 22.04 + RTX 3070 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

step 0 "Toolchain (GCC 14)"         "00-toolchain.sh"
step 1 "Build Dependencies"          "01-deps.sh"
step 2 "Build hypr* Stack"           "02-build-stack.sh"
step 3 "NVIDIA Configuration"        "03-nvidia.sh"
step 4 "Register Wayland Session"    "04-session.sh"
step 5 "Bootstrap hyprland.conf"     "05-config.sh"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  TẤT CẢ BƯỚC HOÀN THÀNH                            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "CHECKLIST TRƯỚC KHI REBOOT:"
echo ""
echo "  [?] Sửa monitor= trong ~/.config/hypr/hyprland.conf"
echo "      cho đúng tên connector của mày (xem bước 5 output)"
echo ""
echo "  [?] Cài terminal: sudo apt-get install -y kitty"
echo "      (hoặc foot: sudo apt-get install -y foot)"
echo ""
echo "  [?] Kiểm tra driver NVIDIA đang chạy:"
echo "      nvidia-smi"
echo ""
echo "Khi sẵn sàng: sudo reboot"
echo "Sau reboot: chọn 'Hyprland' ở màn hình login GDM (icon bánh răng)"
echo ""
echo "Nếu Hyprland không boot:"
echo "  Ctrl+Alt+F2 → login → journalctl -xe | grep -i hypr"
echo "  Rồi đăng nhập vào GNOME thay thế để debug."
