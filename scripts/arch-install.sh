#!/bin/bash
#
# Script automating installation of Arch Linux.

# Partitions
readonly boot_part=''
readonly swap_part='' # optional
readonly root_part=''
readonly var_part='' # optional
readonly home_part='' # optional

# Time zone
readonly region='Europe'
readonly city='Paris'

# Localization
readonly locale='fr_FR.UTF-8 UTF-8'
readonly lang='en_US.UTF-8'
readonly keymap='us'

# Network
readonly hostname=''
readonly connection_type='' # wired | wireless
readonly interface=''

# User
readonly user_name=''

# Misc
readonly cpu_manufacturer='' # intel | amd
readonly ssd='' # yes | no
readonly encryption='' # yes | no

check_vars() {
  case "$connection_type" in
    wired | wireless) ;;
    *)
      echo "Invalid value for connection_type"
      exit
      ;;
  esac

  case "$cpu_manufacturer" in
    intel | amd) ;;
    *)
      echo "Invalid value for cpu_manufacturer"
      exit
      ;;
  esac

  case "$ssd" in
    yes | no) ;;
    *)
      echo "Invalid value for ssd"
      exit
      ;;
  esac

  case "$encryption" in
    yes | no) ;;
    *)
      echo "Invalid value for encryption"
      exit
      ;;
  esac
}

################################################################################
# PRE-CHROOT
################################################################################

prechrt_pre_install() {
  # Update the system clock
  echo "Updating system clock..."
  timedatectl set-ntp true

  # Format the partitions
  echo "Formatting partitions..."
  if [[ -n "$swap_part" ]]; then
    mkswap "$swap_part"
    swapon "$swap_part"
  fi
  mkfs.ext4 "$root_part"
  if [[ -n "$var_part" ]]; then
    mkfs.ext4 "$var_part"
  fi

  # Mount the file systems
  echo "Mounting file systems..."
  mount "$root_part" /mnt
  if [[ -n "$boot_part" ]]; then
    mkdir /mnt/boot
    mount "$boot_part" /mnt/boot
  fi
  if [[ -n "$var_part" ]]; then
    mkdir /mnt/var
    mount "$var_part" /mnt/var
  fi
  if [[ -n "$home_part" ]]; then
    mkdir /mnt/home
    mount "$home_part" /mnt/home
  fi
}

prechrt_install() {
  # Install the base packages
  echo "Installing base packages..."
  pacstrap /mnt base linux linux-firmware vi man-db man-pages texinfo sudo
}

prechrt_configure() {
  # Fstab
  echo "Generating fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab

  # Chroot
  echo "Changing root into the new system..."
  cp "$0" /mnt/root/
  arch-chroot /mnt sh "/root/$0" post-chroot
  rm -f "/mnt/root/$0"
}

################################################################################
# POST-CHROOT
################################################################################

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
  echo "LANG=$lang" > /etc/locale.conf
  echo "KEYMAP=$keymap" > /etc/vconsole.conf

  # Hostname
  echo "Setting hostname..."
  echo "$hostname" > /etc/hostname
  echo "" >> /etc/hosts
  echo -e "127.0.0.1\tlocalhost" >> /etc/hosts
  echo -e "::1\t\tlocalhost" >> /etc/hosts
  echo -e "127.0.1.1\t$hostname.localdomain\t$hostname" >> /etc/hosts

  # Network configuration
  echo "Configuring network..."
  pacman -S --noconfirm dhcpcd netctl wpa_supplicant dialog
  case "$connection_type" in
    wired)
      systemctl enable "dhcpcd@$interface.service"
      ;;
    wireless)
      systemctl enable "netctl-auto@$interface.service"
      ;;
  esac

  # Root password
  echo "Setting root password..."
  passwd

  # Create a new user
  useradd -m -G wheel -s /bin/bash "$user_name"
  echo "Setting password for $user_name..."
  passwd "$user_name"

  # Microcode updates
  echo "Installing required package for microcode updates..."
  case "$cpu_manufacturer" in
    intel)
      pacman -S --noconfirm intel-ucode
      ;;
    amd)
      pacman -S --noconfirm amd-ucode
      ;;
  esac

  # SSD trimming
  case "$ssd" in
    yes)
      echo "An SSD is present in the system, enabling fstrim timer..."
      systemctl enable fstrim.timer
      ;;
    no)
      echo "No SSD is present in the system, skipping..."
      ;;
  esac

  # Boot loader
  echo "Installing boot loader..."
  pacman -S --noconfirm grub efibootmgr os-prober
  grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot \
    --bootloader-id=grub

  # dm-crypt
  case "$encryption" in
    yes)
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
          >> /etc/crypttab
      fi

      local home_uuid="$(get_uuid /home)"
      if [[ -n "$home_uuid" ]]; then
        echo "crypthome      UUID=$home_uuid    none                    luks,discard" \
          >> /etc/crypttab
      fi
      ;;
    no)
      echo "System is not encrypted, skipping..."
      ;;
  esac

  # Boot loader - final installment
  grub-mkconfig -o /boot/grub/grub.cfg
}

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
  ' /etc/pacman.conf > /tmp/pacman.conf
  mv /tmp/pacman.conf /etc/pacman.conf

  echo "Enabling fancy pacman output..."
  sed -i 's/^#\(Color\)/\1/' /etc/pacman.conf
  sed -i '/^# Misc options/a \ILoveCandy' /etc/pacman.conf
}

end_message() {
  cat <<EOF
Installation complete!
You can now reboot into your newly installed system.
EOF
}

check_vars

case "$1" in
  post-chroot)
    postchrt_configure
    apply_tweaks
    end_message
    ;;
  *)
    prechrt_pre_install
    prechrt_install
    prechrt_configure
    ;;
esac
