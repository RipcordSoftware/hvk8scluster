#!/usr/bin/env bash

if [ "$1" == "" ]; then
    echo "Error: you must specify the type of preseed file"
    exit 1
fi

# set the Debian version, defaulting to 10.7.0
DEBIAN_VERSION=${2:-10.7.0}

PRESEED_NAME=${1%.cfg}
PRESEED_FILE="${PRESEED_NAME}.cfg"
REPO_ROOT=$(git rev-parse --show-toplevel)
PUBKEY_FILE="${REPO_ROOT}/src/keys/id_rsa.pub"
ISOFILES_TMP_ROOT="${ISOFILES_TMP_ROOT:-/tmp/isofiles}"
ISOFILES_OUT_ROOT="${REPO_ROOT}/bin/isos"

if [ "$REPO_ROOT" == "" ]; then
    echo "Error: unable to determine the repository root"
    exit 1
fi

if [ ! -f "$PUBKEY_FILE" ]; then
    cp -f ~/.ssh/id_rsa.pub "$PUBKEY_FILE" || cp -f /mnt/c/Users/${USER}/.ssh/id_rsa.pub "$PUBKEY_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: unable to find the public key file"
        exit 2
    fi
fi

cp -f "$PRESEED_FILE" preseed.cfg
if [ $? -ne 0 ]; then
    echo "Error: unable to copy the preseed file '$PRESEED_FILE'"
    exit 3
fi

if [ -d "$ISOFILES_TMP_ROOT" ]; then
  chmod -R 700 "$ISOFILES_TMP_ROOT"
  rm -rf "$ISOFILES_TMP_ROOT"
fi

xorriso -osirrox on -indev "${REPO_ROOT}/src/iso/debian-${DEBIAN_VERSION}-amd64-netinst.iso" -extract / "$ISOFILES_TMP_ROOT"
if [ $? -ne 0 ]; then
    echo "Error: unable to extract the source ISO"
    exit 4
fi

chmod -R 700 "$ISOFILES_TMP_ROOT" && \
cp -Rf ./preseed/ "${ISOFILES_TMP_ROOT}/preseed" && \
cp -f "$PUBKEY_FILE" "${ISOFILES_TMP_ROOT}/preseed"
if [ $? -ne 0 ]; then
    echo "Error: unable to inject the preseed script directory"
    exit 5
fi

gunzip "${ISOFILES_TMP_ROOT}/install.amd/initrd.gz" && \
echo "preseed.cfg" | cpio -H newc -o -A -F "${ISOFILES_TMP_ROOT}/install.amd/initrd" && \
gzip "${ISOFILES_TMP_ROOT}/install.amd/initrd"
if [ $? -ne 0 ]; then
    echo "Error: unable to inject the preseed file"
    exit 6
fi

sed -i 's/timeout 0/timeout 5/' "${ISOFILES_TMP_ROOT}/isolinux/isolinux.cfg" && \
echo -e "\tmenu default" >> "${ISOFILES_TMP_ROOT}/isolinux/txt.cfg"
if [ $? -ne 0 ]; then
    echo "Error: Unable to set the default menu item or timeout"
    exit 7
fi

sed -i $'s/ \'Install\' {/ \'Install\' --id install {/' "${ISOFILES_TMP_ROOT}/boot/grub/grub.cfg" && \
echo 'default=install' >> "${ISOFILES_TMP_ROOT}/boot/grub/grub.cfg" && \
echo 'timeout=5' >> "${ISOFILES_TMP_ROOT}/boot/grub/grub.cfg"
if [ $? -ne 0 ]; then
    echo "Error: unable to update the grub.cfg with default boot options"
    exit 10
fi

pushd "${ISOFILES_TMP_ROOT}"
md5sum $(find -follow -type f) > md5sum.txt; MD5_RESULT=$?
popd
if [ $MD5_RESULT -ne 0 ]; then
    echo "Error: unable to update the MD5 checksums"
    exit 8
fi

mkdir -p "$ISOFILES_OUT_ROOT"

xorriso -as mkisofs \
    -isohybrid-mbr "${ISOFILES_TMP_ROOT}/g2ldr.mbr" \
    -c isolinux/boot.cat \
    -b isolinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "${ISOFILES_OUT_ROOT}/${PRESEED_NAME}-debian-${DEBIAN_VERSION}-amd64-netinst.iso" \
    "$ISOFILES_TMP_ROOT"
if [ $? -ne 0 ]; then
    echo "Error: unable to create the preseed iso file"
    exit 9
fi
