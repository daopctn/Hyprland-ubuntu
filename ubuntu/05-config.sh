#!/usr/bin/env bash
# Bước 6: Tạo hyprland.conf tối thiểu để không sập lần đầu.
#
# CỰC QUAN TRỌNG: thiếu dòng monitor= là treo ngay lập tức.
# Script này tạo config với dual-monitor template cho RTX 3070.
# Mày cần chỉnh đúng tên connector sau khi boot vào Hyprland lần đầu.

set -euo pipefail

HYPR_CONFIG_DIR="${HOME}/.config/hypr"
HYPR_CONFIG="${HYPR_CONFIG_DIR}/hyprland.conf"

echo "[05-config] Tạo thư mục config..."
mkdir -p "${HYPR_CONFIG_DIR}"

if [[ -f "${HYPR_CONFIG}" ]]; then
    echo "[05-config] CẢNH BÁO: ${HYPR_CONFIG} đã tồn tại."
    echo "[05-config] Backup vào ${HYPR_CONFIG}.bak trước khi ghi đè..."
    cp "${HYPR_CONFIG}" "${HYPR_CONFIG}.bak"
fi

echo "[05-config] Ghi config mẫu..."

cat <<'CONFIG' > "${HYPR_CONFIG}"
# hyprland.conf — Config tối thiểu cho Ubuntu 22.04 + RTX 3070
# Generated bởi 05-config.sh
#
# ĐỂ TÌM TÊN CONNECTOR ĐÚNG: chạy lệnh này từ terminal khi đang trong Hyprland:
#   hyprctl monitors all
# Tên thường là: HDMI-A-1, DP-1, DP-2, DP-3 (RTX 3070 không có VGA output)
# Nếu mày dùng DP→VGA adapter thì sẽ thấy DP-X trong hyprctl monitors.

################
# NVIDIA ENV   #
################
source = ~/.config/hypr/nvidia-env.conf

################
# MONITORS     #
################
# Cú pháp: monitor=NAME,RESOLUTION@REFRESH,POSITION,SCALE
#
# Màn hình chính (HDMI):
monitor = HDMI-A-1, 1920x1080@60, 0x0, 1

# Màn hình phụ (DisplayPort — chỉnh DP-1/DP-2/DP-3 cho đúng):
monitor = DP-1, 1920x1080@60, 1920x0, 1

# Fallback: nhận tất cả monitor còn lại ở vị trí auto
monitor = , preferred, auto, 1

################
# CURSOR       #
################
cursor {
    # Bật nếu con trỏ nhấp nháy với NVIDIA — thường cần với RTX series
    no_hardware_cursors = true
}

################
# GENERAL      #
################
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

################
# DECORATION   #
################
decoration {
    rounding = 8
    blur {
        enabled = true
        size = 6
        passes = 2
    }
    shadow {
        enabled = true
        range = 8
        render_power = 2
    }
}

################
# ANIMATIONS   #
################
animations {
    enabled = true
    bezier = easeOut, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 4, easeOut
    animation = windowsOut, 1, 4, easeOut, popin 80%
    animation = border, 1, 8, default
    animation = fade, 1, 5, default
    animation = workspaces, 1, 5, default
}

################
# INPUT        #
################
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = false
    }
    sensitivity = 0
}

################
# LAYOUT       #
################
dwindle {
    pseudotile = true
    preserve_split = true
}

master {
    new_status = master
}

################
# KEYBINDS     #
################
# SUPER là phím Windows/Meta
$mainMod = SUPER

# Terminal — đổi kitty thành foot/alacritty/wezterm nếu cần
bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, V, togglefloating
bind = $mainMod, P, pseudo
bind = $mainMod, J, togglesplit
bind = $mainMod, F, fullscreen

# App launcher (cần rofi hoặc wofi)
bind = $mainMod, D, exec, wofi --show drun

# Screenshot (cần grimblast hoặc grim+slurp)
bind = , Print, exec, grimblast copy area

# Di chuyển focus
bind = $mainMod, left,  movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up,    movefocus, u
bind = $mainMod, down,  movefocus, d

# Di chuyển window
bind = $mainMod SHIFT, left,  movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up,    movewindow, u
bind = $mainMod SHIFT, down,  movewindow, d

# Workspaces 1-9
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9

# Move window đến workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9

# Mouse binds
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

################
# AUTOSTART    #
################
# Wallpaper — cần hyprpaper hoặc swaybg
# exec-once = hyprpaper
# exec-once = swaybg -m fill -i ~/Pictures/wallpaper.jpg

# Status bar
# exec-once = waybar

# Notification daemon
# exec-once = dunst
CONFIG

echo "[05-config] XONG. Config đã tạo tại: ${HYPR_CONFIG}"

# Nhắc nhở về nvidia-env.conf
if [[ ! -f "${HYPR_CONFIG_DIR}/nvidia-env.conf" ]]; then
    echo ""
    echo "[05-config] CẢNH BÁO: nvidia-env.conf chưa có."
    echo "            Chạy 03-nvidia.sh để tạo file đó trước."
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  CONFIG BOOTSTRAP HOÀN THÀNH                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "VIỆC PHẢI LÀM TRƯỚC KHI BOOT HYPRLAND:"
echo ""
echo "1. Tìm đúng tên connector của mày:"
echo "   sudo cat /sys/class/drm/card*/card*-*/status"
echo "   Hoặc sau khi vào Hyprland: hyprctl monitors all"
echo ""
echo "2. Sửa monitor= trong ${HYPR_CONFIG}:"
echo "   RTX 3070 outputs: HDMI-A-1, DP-1, DP-2, DP-3"
echo "   (không có VGA native — VGA adapter sẽ hiện là DP-X)"
echo ""
echo "3. Cài terminal để không bị kẹt:"
echo "   sudo apt-get install -y kitty   (hoặc foot/alacritty)"
