#!/usr/bin/env bash
# Bước 2: Cài toàn bộ build dependencies từ apt.
# Ubuntu 22.04 có sẵn phần lớn, đủ làm nền cho hypr* stack.

set -euo pipefail

echo "[01-deps] Cập nhật danh sách package..."
sudo apt-get update -qq

echo "[01-deps] Cài build tools..."
sudo apt-get install -y \
    git \
    cmake \
    meson \
    ninja-build \
    pkg-config \
    build-essential \
    glslang-tools \
    glslang-dev

echo "[01-deps] Cài Wayland + display server deps..."
sudo apt-get install -y \
    libwayland-dev \
    libwayland-client0 \
    wayland-protocols \
    libxkbcommon-dev \
    libxkbcommon-x11-dev

echo "[01-deps] Cài DRM/KMS + GPU deps..."
sudo apt-get install -y \
    libdrm-dev \
    libgbm-dev \
    libegl-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libgl-dev

echo "[01-deps] Cài input + seat deps..."
sudo apt-get install -y \
    libinput-dev \
    libudev-dev \
    libseat-dev

echo "[01-deps] Cài graphics/rendering deps..."
sudo apt-get install -y \
    libpixman-1-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libpangocairo-1.0-0 \
    libharfbuzz-dev

echo "[01-deps] Cài multimedia + screen capture deps..."
sudo apt-get install -y \
    libpipewire-0.3-dev \
    libspa-0.2-dev

echo "[01-deps] Cài X11 compatibility (XWayland)..."
sudo apt-get install -y \
    libxcb1-dev \
    libxcb-composite0-dev \
    libxcb-dri3-dev \
    libxcb-ewmh-dev \
    libxcb-icccm4-dev \
    libxcb-present-dev \
    libxcb-render-util0-dev \
    libxcb-res0-dev \
    libxcb-shm0-dev \
    libxcb-util-dev \
    libxcb-xfixes0-dev \
    libxcb-xinput-dev \
    libxcb-xkb-dev \
    libx11-xcb-dev \
    xwayland

echo "[01-deps] Cài misc deps (toml, magic, re2, muparser)..."
sudo apt-get install -y \
    libmagic-dev \
    libtomlplusplus-dev \
    libre2-dev \
    libsystemd-dev \
    libliftoff-dev \
    libdisplay-info-dev \
    libffi-dev \
    libuuid1 \
    uuid-dev \
    libpugixml-dev \
    libzip-dev \
    librsvg2-dev \
    libjxl-dev \
    libwebp-dev \
    libmtdev-dev \
    libevdev-dev \
    libwacom-dev \
    libgtk-3-dev \
    libmuparser-dev \
    libxml2-dev \
    libexpat1-dev \
    bison xsltproc \
    python3-jinja2 \
    python3-pip

echo "[01-deps] Nâng cmake >= 3.30 (Hyprland HEAD yêu cầu, Ubuntu 22.04 chỉ có 3.22)..."
pip3 install cmake --upgrade --quiet

echo ""
echo "[01-deps] XONG. Tất cả build dependencies đã được cài."
echo ""
echo "LƯU Ý: 02-build-stack.sh sẽ tự build các thư viện sau từ source"
echo "        vì Ubuntu 22.04 version quá cũ:"
echo "  - wayland      >= 1.22.91  (Ubuntu 22.04: ~1.20)"
echo "  - wayland-protocols >= 1.47  (Ubuntu 22.04: ~1.32)"
echo "  - xkbcommon    >= 1.11.0   (Ubuntu 22.04: 1.4.x)"
echo "  - libinput     >= 1.29     (Ubuntu 22.04: 1.20.x)"
