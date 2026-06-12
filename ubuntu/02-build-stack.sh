#!/usr/bin/env bash
# Bước 3: Build toàn bộ hypr* stack theo đúng thứ tự phụ thuộc.
#
# Thứ tự BẮT BUỘC (cái sau cần cái trước):
#   hyprwayland-scanner → hyprutils → hyprlang → hyprcursor
#   → hyprgraphics → hyprland-protocols → aquamarine → Hyprland
#
# Tất cả cài vào /opt/hypr để không đụng chạm system libs.
# PKG_CONFIG_PATH và CMAKE_PREFIX_PATH phải trỏ vào /opt/hypr trước khi
# build mỗi thành phần — thiếu bước này là symbol lookup error ngay.

set -euo pipefail

# ─── CẤU HÌNH ──────────────────────────────────────────────────────────────
PREFIX=/opt/hypr
SRC_DIR="${HOME}/hypr-src"
JOBS=$(nproc)

export CC=gcc-14
export CXX=g++-14

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="${PREFIX}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH:-}"
export PATH="${PREFIX}/bin:${PATH}"
# ───────────────────────────────────────────────────────────────────────────

die() { echo "[ERROR] $*" >&2; exit 1; }

clone_or_update() {
    local name="$1" url="$2" branch="${3:-main}"
    local dir="${SRC_DIR}/${name}"
    if [[ -d "${dir}/.git" ]]; then
        echo "[build] ${name}: đã có, cập nhật..."
        git -C "$dir" fetch origin
        git -C "$dir" checkout "$branch"
        git -C "$dir" reset --hard "origin/${branch}"
    else
        echo "[build] ${name}: clone từ ${url}..."
        git clone --depth=1 --branch "$branch" "$url" "$dir"
    fi
}

build_cmake() {
    local name="$1"
    local dir="${SRC_DIR}/${name}"
    shift
    echo ""
    echo "══════════════════════════════════════════"
    echo " BUILD CMAKE: ${name}"
    echo "══════════════════════════════════════════"
    cmake -S "$dir" -B "${dir}/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_C_COMPILER=gcc-14 \
        -DCMAKE_CXX_COMPILER=g++-14 \
        "$@"
    cmake --build "${dir}/build" -j"${JOBS}"
    sudo cmake --install "${dir}/build"
}

build_meson() {
    local name="$1"
    local dir="${SRC_DIR}/${name}"
    shift
    echo ""
    echo "══════════════════════════════════════════"
    echo " BUILD MESON: ${name}"
    echo "══════════════════════════════════════════"
    meson setup "${dir}/build" "$dir" \
        --prefix="${PREFIX}" \
        --buildtype=release \
        "$@"
    ninja -C "${dir}/build" -j"${JOBS}"
    sudo ninja -C "${dir}/build" install
}

# ─── SETUP ──────────────────────────────────────────────────────────────────
echo "[build] Tạo thư mục nguồn: ${SRC_DIR}"
mkdir -p "${SRC_DIR}"

echo "[build] Tạo prefix: ${PREFIX}"
sudo mkdir -p "${PREFIX}"/{bin,lib,include,share}

# ─── 1. hyprwayland-scanner ─────────────────────────────────────────────────
# Tool tạo Wayland protocol code — phải có trước khi build bất cứ thứ gì.
clone_or_update hyprwayland-scanner \
    https://github.com/hyprwm/hyprwayland-scanner.git \
    main
build_cmake hyprwayland-scanner

# ─── 2. hyprutils ───────────────────────────────────────────────────────────
# Thư viện nền tảng: SP<>/WP<>/UP<> smart pointers, signals, v.v.
# Mọi thứ đều phụ thuộc vào cái này.
clone_or_update hyprutils \
    https://github.com/hyprwm/hyprutils.git \
    main
build_cmake hyprutils

# ─── 3. hyprlang ────────────────────────────────────────────────────────────
# Parser cho config language của Hyprland (.conf files).
clone_or_update hyprlang \
    https://github.com/hyprwm/hyprlang.git \
    main
build_cmake hyprlang

# ─── 4. hyprcursor ──────────────────────────────────────────────────────────
# Cursor theme loading + rendering.
clone_or_update hyprcursor \
    https://github.com/hyprwm/hyprcursor.git \
    main
build_cmake hyprcursor

# ─── 5. hyprgraphics ────────────────────────────────────────────────────────
# Graphics utilities (image loading, format handling).
clone_or_update hyprgraphics \
    https://github.com/hyprwm/hyprgraphics.git \
    main
build_cmake hyprgraphics

# ─── 6. hyprland-protocols ──────────────────────────────────────────────────
# Wayland protocol extensions riêng của Hyprland.
clone_or_update hyprland-protocols \
    https://github.com/hyprwm/hyprland-protocols.git \
    main
build_meson hyprland-protocols

# ─── 7. aquamarine ──────────────────────────────────────────────────────────
# Backend DRM/KMS mới — thay thế wlroots hoàn toàn.
# WLR_NO_HARDWARE_CURSORS cũ KHÔNG dùng được với aquamarine.
clone_or_update aquamarine \
    https://github.com/hyprwm/aquamarine.git \
    main
build_cmake aquamarine

# ─── 8. Hyprland ────────────────────────────────────────────────────────────
# Build compositor chính — phải là bước cuối cùng.
HYPR_SRC="${SRC_DIR}/Hyprland"
if [[ -d "${HYPR_SRC}/.git" ]]; then
    echo "[build] Hyprland: đã có, bỏ qua clone (dùng source hiện tại)."
else
    # Nếu chạy script này từ ngoài repo, clone về.
    clone_or_update Hyprland \
        https://github.com/hyprwm/Hyprland.git \
        main
fi

echo ""
echo "══════════════════════════════════════════"
echo " BUILD CMAKE: Hyprland"
echo "══════════════════════════════════════════"
cmake -S "${HYPR_SRC}" -B "${HYPR_SRC}/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_C_COMPILER=gcc-14 \
    -DCMAKE_CXX_COMPILER=g++-14

cmake --build "${HYPR_SRC}/build" -j"${JOBS}"
sudo cmake --install "${HYPR_SRC}/build"

# ─── SYMLINK tiện dùng ──────────────────────────────────────────────────────
echo ""
echo "[build] Tạo symlink /usr/local/bin/Hyprland → ${PREFIX}/bin/Hyprland"
sudo ln -sf "${PREFIX}/bin/Hyprland" /usr/local/bin/Hyprland

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  BUILD STACK HOÀN THÀNH                 ║"
echo "║  Hyprland binary: ${PREFIX}/bin/Hyprland"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Bước tiếp theo:"
echo "  ./03-nvidia.sh     — cấu hình NVIDIA RTX 3070"
echo "  ./04-session.sh    — đăng ký Wayland session"
echo "  ./05-config.sh     — tạo hyprland.conf mẫu"
