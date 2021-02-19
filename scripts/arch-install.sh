#!/bin/bash
#
# Script automating installation of Arch Linux.
# Written according to my needs.

readonly region=Europe
readonly city=Paris
readonly locale='fr_FR.UTF-8 UTF-8'
readonly lang=en_US.UTF-8
readonly keymap=us

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  pre-chroot   execute pre-chroot installation process
  post-chroot  execute post-chroot installation process
  tweaks       apply optional tweaks
EOF
}

################################################################################
# PRE-CHROOT
################################################################################

########################################
# Set the following global variables:
#   boot_mode
#   boot
#   swap
#   root
#   var
#   home
########################################
prechrt_prepare() {
  echo "Boot mode:"
  echo "1) BIOS  2) UEFI"
  read boot_mode
  while [[ "$boot_mode" != 1 && "$boot_mode" != 2 ]]; do
    read boot_mode
  done

  lsblk
  echo "Partition for /boot (leave blank if none):"
  read boot
  while [[ -n "$boot" || "$boot_mode" = 2 ]] && [[ ! -b "$boot" ]]; do
    read boot
  done

  echo "Partition for [SWAP] (leave blank if none):"
  read swap
  while [[ -n "$swap" && ! -b "$swap" ]]; do
    read swap
  done

  echo "Partition for /:"
  read root
  while [[ ! -b "$root" ]]; do
    read root
  done

  echo "Partition for /var (leave blank if none):"
  read var
  while [[ -n "$var" && ! -b "$var" ]]; do
    read var
  done

  echo "Partition for /home (leave blank if none):"
  read home
  while [[ -n "$home" && ! -b "$home" ]]; do
    read home
  done
}

prechrt_pre_install() {
  # Update the system clock
  echo "Updating system clock..."
  timedatectl set-ntp true

  # Format the partitions
  echo "Formatting partitions..."
  if [[ -n "$boot" && "$boot_mode" = 1 ]]; then
    mkfs.ext4 "$boot"
  fi
  if [[ -n "$swap" ]]; then
    mkswap "$swap"
    swapon "$swap"
  fi
  mkfs.ext4 "$root"
  if [[ -n "$var" ]]; then
    mkfs.ext4 "$var"
  fi

  # Mount the file systems
  echo "Mounting file systems..."
  mount "$root" /mnt
  if [[ -n "$boot" ]]; then
    mkdir /mnt/boot
    mount "$boot" /mnt/boot
  fi
  if [[ -n "$var" ]]; then
    mkdir /mnt/var
    mount "$var" /mnt/var
  fi
  if [[ -n "$home" ]]; then
    mkdir /mnt/home
    mount "$home" /mnt/home
  fi
}

prechrt_install() {
  # Install the base packages
  echo "Installing base packages..."
  pacstrap /mnt base base-devel
}

prechrt_configure() {
  # Fstab
  echo "Generating fstab..."
  genfstab -U /mnt >>/mnt/etc/fstab

  # Chroot
  echo "Changing root into the new system..."
  cp "$0" /mnt/
  echo "$boot_mode" >/mnt/env.boot_mode
  arch-chroot /mnt
}

################################################################################
# POST-CHROOT
################################################################################

########################################
# Set the following global variables:
#   boot_mode
#   hostname
#   connection_type
#   interface
#   cpu_manufacturer
#   ssd
#   encryption
########################################
postchrt_prepare() {
  boot_mode="$(<env.boot_mode)"

  echo "Define hostname:"
  read hostname
  while [[ -z "$hostname" ]]; do
    read hostname
  done

  echo "Which type of connection do you use?"
  echo "1) Wired  2) Wireless"
  read connection_type
  while [[ "$connection_type" != 1 && "$connection_type" != 2 ]]; do
    read connection_type
  done

  ip link
  echo "Enter the name of the network interface you want to use:"
  read interface
  while [[ -z "$(grep "^$interface:" /proc/net/dev)" ]]; do
    read interface
  done

  echo "Which manufacturer is your CPU from?"
  echo "1) Intel  2) AMD"
  read cpu_manufacturer
  while [[ "$cpu_manufacturer" != 1 && "$cpu_manufacturer" != 2 ]]; do
    read cpu_manufacturer
  done

  echo "Are you using an SSD? [y/n]"
  read ssd
  while [[ "$ssd" != y && "$ssd" != n ]]; do
    read ssd
  done

  echo "Is your system encrypted? [y/n]"
  read encryption
  while [[ "$encryption" != y && "$encryption" != n ]]; do
    read encryption
  done
}

get_uuid() {
  local mountpoint="$1"

  local device="$(lsblk \
    | awk "/\\$mountpoint$/ { print device } { device = \$1 }" \
    | sed 's/^[^a-z0-9]*\([a-z0-9]*\)$/\/dev\/\1/')"
  echo "$(blkid "$device" | sed 's/^.* UUID="\(.*\)" TYPE=.*$/\1/')"
}

postchrt_configure() {
  # Time zone
  echo "Setting time zone..."
  ln -sf "/usr/share/zoneinfo/$region/$city" /etc/localtime
  hwclock --systohc

  # Locale
  echo "Applying locale settings..."
  sed -i 's/^#\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  sed -i "s/^#\($locale\)/\1/" /etc/locale.gen
  locale-gen
  echo "LANG=$lang" >/etc/locale.conf
  echo "KEYMAP=$keymap" >/etc/vconsole.conf

  # Hostname
  echo "Setting hostname..."
  echo "$hostname" >/etc/hostname
  echo "" >>/etc/hosts
  echo -e "127.0.0.1\tlocalhost" >>/etc/hosts
  echo -e "::1\t\tlocalhost" >>/etc/hosts
  echo -e "127.0.1.1\t$hostname.localdomain\t$hostname" >>/etc/hosts

  # Network configuration
  echo "Configuring network..."
  case "$connection_type" in
  1)
    systemctl enable "dhcpcd@$interface.service"
    ;;
  2)
    pacman -S --noconfirm wpa_supplicant dialog
    systemctl enable "netctl-auto@$interface.service"
    ;;
  esac

  # Root password
  echo "Setting root password..."
  passwd

  # Create a new user
  echo "Enter login for new user:"
  read login
  while [[ -z "$login" ]]; do
    read login
  done

  useradd -m -G wheel -s /bin/bash "$login"
  passwd "$login"

  # Microcode updates
  echo "Installing required package for microcode updates..."
  case "$cpu_manufacturer" in
  1)
    pacman -S --noconfirm intel-ucode
    ;;
  2)
    pacman -S --noconfirm amd-ucode
    ;;
  esac

  # SSD trimming
  case "$ssd" in
  y)
    echo "An SSD is present in the system, enabling fstrim timer..."
    systemctl enable fstrim.timer
    ;;
  n)
    echo "No SSD is present in the system, skipping..."
    ;;
  esac

  # Boot loader
  echo "Installing boot loader..."
  case "$boot_mode" in
  1)
    pacman -S --noconfirm grub os-prober
    grub-install --target=i386-pc /dev/sda
    ;;
  2)
    pacman -S --noconfirm grub efibootmgr os-prober
    grub-install \
      --target=x86_64-efi \
      --efi-directory=/boot \
      --bootloader-id=grub
    ;;
  esac

  # dm-crypt
  case "$encryption" in
  y)
    echo "System is encrypted, configuring mkinitcpio, boot loader and crypttab..."

    sed -i 's/^\(HOOKS=.*\)udev/\1systemd/' /etc/mkinitcpio.conf
    sed -i 's/^\(HOOKS=.*\)\(filesystems\)/\1sd-encrypt \2/' \
      /etc/mkinitcpio.conf
    mkinitcpio -P

    local root_uuid="$(get_uuid /)"
    sed -i "s/^\(GRUB_CMDLINE_LINUX=\"\)/\1rd.luks.name=$root_uuid=cryptroot rd.luks.options=discard root=\/dev\/mapper\/cryptroot/" \
      /etc/default/grub

    local var_uuid="$(get_uuid /var)"
    if [[ -n "$var_uuid" ]]; then
      echo "cryptvar       UUID=$var_uuid    none                    luks,discard" \
        >>/etc/crypttab
    fi

    local home_uuid="$(get_uuid /home)"
    if [[ -n "$home_uuid" ]]; then
      echo "crypthome      UUID=$home_uuid    none                    luks,discard" \
        >>/etc/crypttab
    fi
    ;;
  n)
    echo "System is not encrypted, skipping..."
    ;;
  esac

  # Boot loader - final installment
  grub-mkconfig -o /boot/grub/grub.cfg

  # Cleaning
  rm -f env.boot_mode

  cat <<EOF
Installation complete!
You can now apply the optional system tweaks or simply reboot into your newly
installed system.
EOF
}

################################################################################
# TWEAKS
################################################################################

apply_tweaks() {
  echo "Configuring sudoers..."
  cp /etc/sudoers /etc/sudoers.bak
  sed -i 's/^# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers

  echo "Enabling multilib repository..."
  cp /etc/pacman.conf /etc/pacman.conf.bak
  sed -i 's/^#\(\[multilib\]\)/\1/' /etc/pacman.conf
  awk '
    /^#Include/ {
      if (prev == "[multilib]") {
        sub(/^#Include/, "Include")
      }
    }
    { print }
    { prev = $0 }
  ' /etc/pacman.conf >/tmp/pacman.conf
  mv /tmp/pacman.conf /etc/pacman.conf

  echo "Enabling fancy pacman output..."
  sed -i 's/^#\(Color\)/\1/' /etc/pacman.conf
  sed -i '/^# Misc options/a \ILoveCandy' /etc/pacman.conf

  cat <<EOF
Tweaks applied successfully!
You can now reboot into your newly installed system.
EOF
}

case "$1" in
pre-chroot)
  prechrt_prepare
  prechrt_pre_install
  prechrt_install
  prechrt_configure
  ;;
post-chroot)
  postchrt_prepare
  postchrt_configure
  ;;
tweaks)
  apply_tweaks
  ;;
*)
  usage
  ;;
esac
