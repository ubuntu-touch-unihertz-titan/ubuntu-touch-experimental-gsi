#!/bin/bash
set -xe
shopt -s extglob

[ -d build ] || git clone https://gitlab.com/ubports/community-ports/halium-generic-adaptation-build-tools build

BUILD_DIR=
OUT=

while [ $# -gt 0 ]
do
    case "$1" in
    (-b) BUILD_DIR="$(realpath "$2")"; shift;;
    (-o) OUT="$2"; shift;;
    (-*) echo "$0: Error: unknown option $1" 1>&2; exit 1;;
    (*) OUT="$2"; break;;
    esac
    shift
done

OUT="$(realpath "$OUT" 2>/dev/null || echo 'out')"
mkdir -p "$OUT"

if [ -z "$BUILD_DIR" ]; then
    TMP=$(mktemp -d)
    TMPDOWN=$(mktemp -d)
else
    TMP="$BUILD_DIR/tmp"
    # Clean up installation dir in case of local builds
    rm -rf "$TMP"
    mkdir -p "$TMP"
    TMPDOWN="$BUILD_DIR/downloads"
    mkdir -p "$TMPDOWN"
fi

HERE=$(pwd)
SCRIPT="$(dirname "$(realpath "$0")")"/build
if [ ! -d "$SCRIPT" ]; then
    SCRIPT="$(dirname "$SCRIPT")"
fi

mkdir -p "${TMP}/system" "${TMP}/partitions"

source "${HERE}/deviceinfo"

cp -av overlay/* "${TMP}/"
if [ -d overlay-${deviceinfo_codename} ]; then
    cp -av overlay-${deviceinfo_codename}/* "${TMP}/"
fi

INITRC_PATHS="
${TMP}/system/opt/halium-overlay/system/etc/init
${TMP}/system/usr/share/halium-overlay/system/etc/init
${TMP}/system/opt/halium-overlay/vendor/etc/init
${TMP}/system/usr/share/halium-overlay/vendor/etc/init
${TMP}/system/android/system/etc/init
${TMP}/system/android/vendor/etc/init
"
while IFS= read -r path ; do
    if [ -d "$path" ]; then
        find "$path" -type f -exec chmod 644 {} \;
    fi
done <<< "$INITRC_PATHS"

BUILDPROP_PATHS="
${TMP}/system/opt/halium-overlay/system
${TMP}/system/usr/share/halium-overlay/system
${TMP}/system/opt/halium-overlay/vendor
${TMP}/system/usr/share/halium-overlay/vendor
${TMP}/system/android/system
${TMP}/system/android/vendor
"
while IFS= read -r path ; do
    if [ -d "$path" ]; then
        find "$path" -type f \( -name "prop.halium" -o -name "build.prop" \) -exec chmod 600 {} \;
    fi
done <<< "$BUILDPROP_PATHS"

# Create empty boot.img to workaround build-tarball-mainline.sh check
touch "${TMP}/partitions/boot.img"

if [ -z "$deviceinfo_use_overlaystore" ]; then
    # create device tarball for https://wiki.debian.org/UsrMerge rootfs
    "$SCRIPT/build-tarball-mainline.sh" "${deviceinfo_codename}" "${OUT}" "${TMP}" "usrmerge"
else
    "$SCRIPT/build-tarball-mainline.sh" "${deviceinfo_codename}" "${OUT}" "${TMP}" "overlaystore"
fi
# compatibility symlink for  _usrmerge variant so that old pipelines just work
ln -f "${OUT}/device_${deviceinfo_codename}.tar.xz" "${OUT}/device_${deviceinfo_codename}_usrmerge.tar.xz"
ln -f "${OUT}/device_${deviceinfo_codename}.tar.build" "${OUT}/device_${deviceinfo_codename}_usrmerge.tar.build"

if [ -z "$BUILD_DIR" ]; then
    rm -r "${TMP}"
    rm -r "${TMPDOWN}"
fi

echo "done"
