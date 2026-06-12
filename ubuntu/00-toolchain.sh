#!/usr/bin/env bash
# Bước 1: Cài GCC 14 qua PPA — KHÔNG đặt làm compiler default hệ thống.
#
# Hyprland HEAD dùng C++26 features (vd: ofstream::native_handle()),
# KHÔNG phải C++23. GCC 11 (22.04 default) và GCC 13 đều không đủ.
# GCC 14 + -std=gnu++26 là combination duy nhất đã verified build được.
#
# Compiler mới chỉ được gọi lúc build Hyprland, radar/Qt vẫn ăn GCC 11 bình thường.

set -euo pipefail

REQUIRED_GCC=14

echo "[00-toolchain] Thêm PPA ubuntu-toolchain-r/test..."
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get update -qq

echo "[00-toolchain] Cài gcc-${REQUIRED_GCC} và g++-${REQUIRED_GCC}..."
sudo apt-get install -y \
    gcc-${REQUIRED_GCC} \
    g++-${REQUIRED_GCC}

echo "[00-toolchain] Kiểm tra phiên bản..."
gcc-${REQUIRED_GCC} --version | head -1
g++-${REQUIRED_GCC} --version | head -1

echo ""
echo "[00-toolchain] XONG. GCC ${REQUIRED_GCC} đã có tại /usr/bin/gcc-${REQUIRED_GCC}."
echo "              Default hệ thống (gcc $(gcc --version | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1)) KHÔNG bị thay đổi."
echo "              Build stack Hyprland sẽ trỏ thẳng vào gcc-${REQUIRED_GCC}."
