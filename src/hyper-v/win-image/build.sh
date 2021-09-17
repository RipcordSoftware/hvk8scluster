#!/usr/bin/env bash

# set the Windows ISO name
WIN_ISO=${2:-en_windows_server_version_20h2_updated_march_2021_x64_dvd_0ccc98b9.iso}

REPO_ROOT=$(git rev-parse --show-toplevel)
PUBKEY_FILE="${REPO_ROOT}/src/keys/id_rsa.pub"
ISOFILES_TMP_ROOT="${ISOFILES_TMP_ROOT:-/tmp/isofiles}"
EFIFILE="${EFIFILE:-/tmp/efi.img}"
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

# TODO: restore
# if [ -d "$ISOFILES_TMP_ROOT" ]; then
#   chmod -R 700 "$ISOFILES_TMP_ROOT"
#   rm -rf "$ISOFILES_TMP_ROOT"
# fi

# TODO: restore
# 7z x "${REPO_ROOT}/src/iso/${WIN_ISO}" "-o${ISOFILES_TMP_ROOT}"
# if [ $? -ne 0 ]; then
#     echo "Error: unable to extract the source ISO"
#     exit 4
# fi

dd if=/dev/zero "of=${EFIFILE}" count=32 bs=1M
if [ $? -ne 0 ]; then
    echo "Error: unable to create the EFI image file"
    exit 5
fi

echo 'label: dos' | sfdisk "${EFIFILE}"
if [ $? -ne 0 ]; then
    echo "Error: unable to partition the EFI image file"
    exit 6
fi

mkfs.vfat "${EFIFILE}"
if [ $? -ne 0 ]; then
    echo "Error: unable to format the EFI image file"
    exit 7
fi

mcopy -s -i "${EFIFILE}" "${ISOFILES_TMP_ROOT}/efi/" ::
if [ $? -ne 0 ]; then
    echo "Error: unable to copy the EFI boot files to the EFI image file"
    exit 8
fi

cp -f CoreUnattend.xml "${ISOFILES_TMP_ROOT}/autounattend.xml"

mkdir -p "${ISOFILES_TMP_ROOT}"'/rs/'
cp -fr ./rs/ "${ISOFILES_TMP_ROOT}"
cp -f "${PUBKEY_FILE}" "${ISOFILES_TMP_ROOT}"'/rs/'

xorriso -as mkisofs -o "${ISOFILES_OUT_ROOT}/${WIN_ISO}" -iso-level 3 -V UEFI "${ISOFILES_TMP_ROOT}" "${EFIFILE}" -e /efi.img -no-emul-boot -joliet -joliet-long
if [ $? -ne 0 ]; then
    echo "Error: unable to create the bootable ISO file"
    exit 9
fi
