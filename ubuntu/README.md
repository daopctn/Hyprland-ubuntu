# Hyprland — Ubuntu 22.04 Build Guide

Build scripts cho **Ubuntu 22.04 LTS** + **NVIDIA RTX 3070**, sử dụng aquamarine backend (không phải wlroots).

## Cấu trúc

| Script | Bước | Mô tả |
|--------|------|-------|
| `00-toolchain.sh` | 1 | Cài GCC 14 qua PPA (không đặt làm default) |
| `01-deps.sh` | 2 | Cài toàn bộ build deps qua apt |
| `02-build-stack.sh` | 3 | Build hypr* stack theo đúng thứ tự |
| `03-nvidia.sh` | 4 | Cấu hình NVIDIA (modeset, initramfs, env vars) |
| `04-session.sh` | 5 | Đăng ký Hyprland session với GDM/LightDM |
| `05-config.sh` | 6 | Tạo `~/.config/hypr/hyprland.conf` mẫu |
| `build-all.sh` | — | Chạy tất cả bước một lần |

## Thứ tự build stack (bắt buộc)

```
hyprwayland-scanner  ← tool tạo protocol code
    → hyprutils       ← SP<>/WP<>/UP<> smart pointers, signals
    → hyprlang        ← config parser
    → hyprcursor      ← cursor rendering
    → hyprgraphics    ← image/format utilities
    → hyprland-protocols ← Wayland protocol extensions
    → aquamarine      ← DRM/KMS backend (thay wlroots)
    → Hyprland        ← compositor (build cuối cùng)
```

Tất cả cài vào `/opt/hypr` — không đụng chạm system libs.

## Chạy nhanh

```bash
cd ubuntu/
chmod +x *.sh
./build-all.sh
# sau đó reboot
```

## Chạy từng bước

```bash
chmod +x *.sh
./00-toolchain.sh
./01-deps.sh
./02-build-stack.sh
./03-nvidia.sh
./04-session.sh
./05-config.sh
sudo reboot
```

## Lưu ý NVIDIA

- `WLR_NO_HARDWARE_CURSORS` là biến cũ của wlroots — **KHÔNG dùng được** với Hyprland mới.
- Thay vào đó dùng `cursor { no_hardware_cursors = true }` trong `hyprland.conf`.
- `nvidia-drm.modeset=1` là **bắt buộc** — thiếu là Hyprland không start.

## Tìm đúng tên connector

RTX 3070 có: HDMI 2.1 × 1, DisplayPort 1.4a × 3. Không có VGA native.

```bash
# Trước khi vào Hyprland
sudo cat /sys/class/drm/card*/card*-*/status

# Khi đang trong Hyprland
hyprctl monitors all
```

Connector names thường là: `HDMI-A-1`, `DP-1`, `DP-2`, `DP-3`.

## Nếu Hyprland không boot

1. `Ctrl+Alt+F2` → login vào TTY
2. `journalctl -xe | grep -i hypr` để xem lỗi
3. Đăng nhập vào GNOME thay thế để debug
4. Kiểm tra `cat /sys/module/nvidia_drm/parameters/modeset` → phải ra `Y`
