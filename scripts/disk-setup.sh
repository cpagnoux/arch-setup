#!/bin/bash
#
# Script setting up the disk(s) for the purpose of installing Arch Linux.
# Uses dm-crypt and LUKS containers for system encryption.

readonly install_drive=''
readonly root_end='50GiB'

# Optional - only if a secondary drive is used for installation
readonly secondary_drive=''
readonly var_end='50GiB'

make_efi_partition() {
  local device="$1"

  parted --script "$device" mkpart EFI fat32 1MiB 513MiB
  parted --script "$device" set 1 esp on
}

luks_init() {
  local device="$1"
  local name="$2"

  cryptsetup -y -v luksFormat "$device" /root/keyfile
  cryptsetup open "$device" "$name"
  mkfs.ext4 "/dev/mapper/$name"
}

setup_single_drive() {
  parted --script "$install_drive" mklabel gpt
  make_efi_partition "$install_drive"
  parted --script "$install_drive" mkpart root ext4 513MiB "$root_end"
  parted --script "$install_drive" mkpart home ext4 "$root_end" 100%

  mkfs.fat -F32 "${install_drive}1"

  luks_init "${install_drive}2" cryptroot
  luks_init "${install_drive}3" crypthome
}

setup_two_drives() {
  parted --script "$install_drive" mklabel gpt
  make_efi_partition "$install_drive"
  parted --script "$install_drive" mkpart root ext4 513MiB 100%

  parted --script "$secondary_drive" mklabel gpt
  parted --script "$secondary_drive" mkpart var ext4 1MiB "$var_end"
  parted --script "$secondary_drive" mkpart home ext4 "$var_end" 100%

  mkfs.fat -F32 "${install_drive}1"

  luks_init "${install_drive}2" cryptroot
  luks_init "${secondary_drive}1" cryptvar
  luks_init "${secondary_drive}2" crypthome
}

if [[ -z "$install_drive" ]]; then
  echo "install_drive should be set"
  exit
fi

if [[ ! -f /root/keyfile ]]; then
  echo "/root/keyfile is missing"
  exit
fi

if [[ -n "$secondary_drive" ]]; then
  setup_two_drives
else
  setup_single_drive
fi
