#!/usr/bin/env bash
# Bước 3: Build toàn bộ hypr* stack theo đúng thứ tự phụ thuộc.
#
# Thứ tự BẮT BUỘC (cái sau cần cái trước):
#   [system libs] cmake pip → wayland → wayland-protocols → xkbcommon
#                 → libinput → muparser
#   [hypr stack]  hyprwayland-scanner → hyprutils → hyprlang → hyprcursor
#                 → hyprgraphics → hyprland-protocols → aquamarine → Hyprland
#
# Tất cả cài vào /opt/hypr để không đụng chạm system libs.
#
# ── PHÁT HIỆN TỪ BUILD THỰC TẾ (quan trọng) ────────────────────────────────
# • hyprutils dùng ofstream::native_handle() — C++26 feature, PHẢI dùng
#   -std=gnu++26, KHÔNG phải -std=c++23
# • hyprland-protocols đã chuyển sang CMake, KHÔNG còn dùng meson
# • aquamarine cần libinput >= 1.26, Ubuntu 22.04 chỉ có 1.21 → build từ source
# • Hyprland HEAD cần: cmake>=3.30, wayland-server>=1.22.91,
#   wayland-protocols>=1.47, xkbcommon>=1.11, libinput>=1.29, muparser
#   (Ubuntu 22.04 không có bất kỳ cái nào đủ version)
# • Aquamarine: linker cần explicit -L/opt/hypr/lib để ưu tiên /opt/hypr
#   libinput thay vì system libinput cũ
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── CẤU HÌNH ──────────────────────────────────────────────────────────────
PREFIX=/opt/hypr
SRC_DIR="${HOME}/hypr-src"
JOBS=$(nproc)

export CC=gcc-14
export CXX=g++-14

# /opt/hypr có thể có pkgconfig ở cả lib/pkgconfig và lib/x86_64-linux-gnu/pkgconfig
_pkg_path="${PREFIX}/lib/pkgconfig:${PREFIX}/lib/x86_64-linux-gnu/pkgconfig:${PREFIX}/share/pkgconfig"
export PKG_CONFIG_PATH="${_pkg_path}:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="${PREFIX}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export PATH="${PREFIX}/bin:${PATH}"

# Linker flags: ưu tiên /opt/hypr libs trước system libs
_lflags="-L${PREFIX}/lib -L${PREFIX}/lib/x86_64-linux-gnu -Wl,-rpath,${PREFIX}/lib"
# ───────────────────────────────────────────────────────────────────────────

die() { echo "[ERROR] $*" >&2; exit 1; }

clone_or_update() {
    local name="$1" url="$2" ref="${3:-main}"
    local dir="${SRC_DIR}/${name}"
    if [[ -d "${dir}/.git" ]]; then
        echo "[build] ${name}: đã có, cập nhật..."
        git -C "$dir" fetch --depth=1 origin "$ref"
        git -C "$dir" reset --hard FETCH_HEAD
    else
        echo "[build] ${name}: clone từ ${url} (ref: ${ref})..."
        git clone --depth=1 --branch "$ref" "$url" "$dir"
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
    rm -rf "${dir}/build"
    PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" \
    cmake -S "$dir" -B "${dir}/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_C_COMPILER=gcc-14 \
        -DCMAKE_CXX_COMPILER=g++-14 \
        -DCMAKE_CXX_FLAGS="-std=gnu++26" \
        -DCMAKE_EXE_LINKER_FLAGS="${_lflags}" \
        -DCMAKE_SHARED_LINKER_FLAGS="${_lflags}" \
        "$@"
    cmake --build "${dir}/build" -j"${JOBS}"
    sudo cmake --install "${dir}/build"

    # Symlink pkgconfig nếu meson install vào lib/x86_64-linux-gnu/pkgconfig
    if ls "${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/"*.pc &>/dev/null; then
        sudo cp "${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/"*.pc \
                "${PREFIX}/lib/pkgconfig/" 2>/dev/null || true
    fi
}

build_meson() {
    local name="$1"
    local dir="${SRC_DIR}/${name}"
    shift
    echo ""
    echo "══════════════════════════════════════════"
    echo " BUILD MESON: ${name}"
    echo "══════════════════════════════════════════"
    rm -rf "${dir}/build"
    PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" \
    meson setup "${dir}" "${dir}/build" \
        --prefix="${PREFIX}" \
        --buildtype=release \
        "$@"
    ninja -C "${dir}/build" -j"${JOBS}"
    sudo ninja -C "${dir}/build" install

    # Symlink pkgconfig nếu cần
    if ls "${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/"*.pc &>/dev/null; then
        sudo cp "${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/"*.pc \
                "${PREFIX}/lib/pkgconfig/" 2>/dev/null || true
    fi
}

# ─── SETUP ──────────────────────────────────────────────────────────────────
echo "[build] Tạo thư mục nguồn: ${SRC_DIR}"
mkdir -p "${SRC_DIR}"

echo "[build] Tạo prefix: ${PREFIX}"
sudo mkdir -p "${PREFIX}"/{bin,lib,include,share,lib/pkgconfig,share/pkgconfig}

# ─── PRE-REQS: cmake >= 3.30, pip ───────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo " PRE-REQ: cmake >= 3.30"
echo "══════════════════════════════════════════"
CMAKE_VER=$(cmake --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1)
MAJOR=${CMAKE_VER%%.*}
MINOR=${CMAKE_VER##*.}
if [[ "$MAJOR" -lt 3 ]] || { [[ "$MAJOR" -eq 3 ]] && [[ "$MINOR" -lt 30 ]]; }; then
    echo "[build] cmake ${CMAKE_VER} < 3.30, nâng cấp qua pip3..."
    pip3 install cmake --upgrade --quiet
    echo "[build] cmake mới: $(cmake --version | head -1)"
else
    echo "[build] cmake ${CMAKE_VER} đủ rồi."
fi

# ─── PRE-REQS: muparser ─────────────────────────────────────────────────────
if ! PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" pkg-config --exists muparser 2>/dev/null; then
    echo "[build] muparser chưa có, cài từ apt hoặc build..."
    if apt-get install -y libmuparser-dev 2>/dev/null | grep -q 'newly installed'; then
        echo "[build] muparser installed via apt."
    else
        clone_or_update muparser https://github.com/beltoforion/muparser.git v2.3.5
        build_cmake muparser -DENABLE_SAMPLES=OFF -DENABLE_OPENMP=OFF
    fi
fi

# ─── PRE-REQS: wayland >= 1.22.91 ───────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo " PRE-REQ: wayland >= 1.22.91"
echo "══════════════════════════════════════════"
WL_VER=$(PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" pkg-config --modversion wayland-server 2>/dev/null || echo "0")
if python3 -c "from packaging.version import Version; exit(0 if Version('${WL_VER}') >= Version('1.22.91') else 1)" 2>/dev/null || \
   [[ "$(printf '%s\n' '1.22.91' "${WL_VER}" | sort -V | head -1)" == "1.22.91" && "${WL_VER}" != "0" ]]; then
    echo "[build] wayland ${WL_VER} đủ rồi."
else
    echo "[build] wayland ${WL_VER} < 1.22.91, build từ source..."
    sudo apt-get install -y libxml2-dev libexpat1-dev 2>/dev/null | tail -1
    # wayland 1.23.1 là stable mới nhất
    clone_or_update wayland \
        https://gitlab.freedesktop.org/wayland/wayland.git \
        1.23.1
    build_meson wayland -Ddocumentation=false -Dtests=false
fi

# ─── PRE-REQS: wayland-protocols >= 1.47 ────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo " PRE-REQ: wayland-protocols >= 1.47"
echo "══════════════════════════════════════════"
WLP_VER=$(PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" pkg-config --modversion wayland-protocols 2>/dev/null || echo "0")
if [[ "$(printf '%s\n' '1.47' "${WLP_VER}" | sort -V | head -1)" == "1.47" && "${WLP_VER}" != "0" ]]; then
    echo "[build] wayland-protocols ${WLP_VER} đủ rồi."
else
    echo "[build] wayland-protocols ${WLP_VER} < 1.47, build từ source..."
    clone_or_update wayland-protocols \
        https://gitlab.freedesktop.org/wayland/wayland-protocols.git \
        1.47
    build_meson wayland-protocols -Dtests=false
fi

# ─── PRE-REQS: xkbcommon >= 1.11.0 ─────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo " PRE-REQ: xkbcommon >= 1.11.0"
echo "══════════════════════════════════════════"
XKB_VER=$(PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" pkg-config --modversion xkbcommon 2>/dev/null || echo "0")
if [[ "$(printf '%s\n' '1.11.0' "${XKB_VER}" | sort -V | head -1)" == "1.11.0" && "${XKB_VER}" != "0" ]]; then
    echo "[build] xkbcommon ${XKB_VER} đủ rồi."
else
    echo "[build] xkbcommon ${XKB_VER} < 1.11.0, build từ source..."
    sudo apt-get install -y bison xsltproc 2>/dev/null | tail -1
    clone_or_update xkbcommon \
        https://github.com/xkbcommon/libxkbcommon.git \
        xkbcommon-1.8.1
    build_meson xkbcommon \
        -Denable-docs=false \
        -Denable-wayland=true \
        -Denable-x11=true \
        -Denable-xkbregistry=true
fi

# ─── PRE-REQS: libinput >= 1.29 ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo " PRE-REQ: libinput >= 1.29"
echo "══════════════════════════════════════════"
LI_VER=$(PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" pkg-config --modversion libinput 2>/dev/null || echo "0")
if [[ "$(printf '%s\n' '1.29' "${LI_VER}" | sort -V | head -1)" == "1.29" && "${LI_VER}" != "0" ]]; then
    echo "[build] libinput ${LI_VER} đủ rồi."
else
    echo "[build] libinput ${LI_VER} < 1.29, build từ source..."
    sudo apt-get install -y libmtdev-dev libevdev-dev libwacom-dev \
        python3-jinja2 libgtk-3-dev 2>/dev/null | tail -2
    clone_or_update libinput \
        https://gitlab.freedesktop.org/libinput/libinput.git \
        1.29.0
    build_meson libinput \
        -Dtests=false \
        -Ddocumentation=false \
        -Ddebug-gui=false \
        -Dlibwacom=false
    # libinput install vào lib/x86_64-linux-gnu — symlink về lib để linker tìm thấy
    sudo ln -sf "${PREFIX}/lib/x86_64-linux-gnu/libinput.so"* "${PREFIX}/lib/" 2>/dev/null || true
    sudo cp "${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/libinput.pc" \
            "${PREFIX}/lib/pkgconfig/" 2>/dev/null || true
fi

# ─── 1. hyprwayland-scanner ─────────────────────────────────────────────────
# Tool tạo Wayland protocol code — phải có trước khi build bất cứ thứ gì.
# Cần: pugixml
sudo apt-get install -y libpugixml-dev 2>/dev/null | tail -1
clone_or_update hyprwayland-scanner \
    https://github.com/hyprwm/hyprwayland-scanner.git \
    main
build_cmake hyprwayland-scanner

# ─── 2. hyprutils ───────────────────────────────────────────────────────────
# Thư viện nền tảng: SP<>/WP<>/UP<> smart pointers, signals, v.v.
# QUAN TRỌNG: dùng ofstream::native_handle() (C++26) → -std=gnu++26 bắt buộc.
clone_or_update hyprutils \
    https://github.com/hyprwm/hyprutils.git \
    main
build_cmake hyprutils

# ─── 3. hyprlang ────────────────────────────────────────────────────────────
clone_or_update hyprlang \
    https://github.com/hyprwm/hyprlang.git \
    main
build_cmake hyprlang

# ─── 4. hyprcursor ──────────────────────────────────────────────────────────
sudo apt-get install -y libzip-dev librsvg2-dev libtomlplusplus-dev 2>/dev/null | tail -1
clone_or_update hyprcursor \
    https://github.com/hyprwm/hyprcursor.git \
    main
build_cmake hyprcursor

# ─── 5. hyprgraphics ────────────────────────────────────────────────────────
sudo apt-get install -y libjxl-dev libwebp-dev 2>/dev/null | tail -1
clone_or_update hyprgraphics \
    https://github.com/hyprwm/hyprgraphics.git \
    main
build_cmake hyprgraphics

# ─── 6. hyprland-protocols ──────────────────────────────────────────────────
# QUAN TRỌNG: đã chuyển sang CMake từ meson — dùng build_cmake không phải build_meson.
clone_or_update hyprland-protocols \
    https://github.com/hyprwm/hyprland-protocols.git \
    main
build_cmake hyprland-protocols

# ─── 7. aquamarine ──────────────────────────────────────────────────────────
# Backend DRM/KMS mới — thay thế wlroots hoàn toàn.
# WLR_NO_HARDWARE_CURSORS cũ KHÔNG dùng được với aquamarine.
sudo apt-get install -y libdisplay-info-dev 2>/dev/null | tail -1
clone_or_update aquamarine \
    https://github.com/hyprwm/aquamarine.git \
    main
build_cmake aquamarine

# ─── 8. Hyprland ────────────────────────────────────────────────────────────
# Build compositor chính — phải là bước cuối cùng.
HYPR_SRC="${SRC_DIR}/Hyprland"
if [[ -d "${HYPR_SRC}/.git" ]]; then
    echo "[build] Hyprland: đã có source tại ${HYPR_SRC}"
    git -C "${HYPR_SRC}" submodule update --init --recursive
else
    clone_or_update Hyprland \
        https://github.com/hyprwm/Hyprland.git \
        main
    git -C "${HYPR_SRC}" submodule update --init --recursive
fi

echo ""
echo "══════════════════════════════════════════"
echo " BUILD CMAKE: Hyprland"
echo "══════════════════════════════════════════"
rm -rf "${HYPR_SRC}/build"
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" \
cmake -S "${HYPR_SRC}" -B "${HYPR_SRC}/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_C_COMPILER=gcc-14 \
    -DCMAKE_CXX_COMPILER=g++-14 \
    -DCMAKE_CXX_FLAGS="-std=gnu++26" \
    -DCMAKE_EXE_LINKER_FLAGS="${_lflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${_lflags}"

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
