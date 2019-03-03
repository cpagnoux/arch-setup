#!/bin/bash
#
# Script automating installation of Arch Linux.
# Written according to my needs.

readonly region='Europe'
readonly city='Paris'
readonly locale='fr_FR.UTF-8 UTF-8'
readonly lang='en_US.UTF-8'
readonly keymap='us'

usage() {
	cat << EOF
Usage: $0 COMMAND

Commands:
  pre-chroot   execute pre-chroot installation process
  post-chroot  execute post-chroot installation process
  tweaks       apply optional tweaks
EOF
}

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
	genfstab -U /mnt >> /mnt/etc/fstab

	# Chroot
	echo "Changing root into the new system..."
	cp "$0" /mnt/
	echo "$boot_mode" > /mnt/BOOT_MODE
	arch-chroot /mnt
}

########################################
# Set the following global variables:
#   boot_mode
#   hostname
#   connection_type
#   interface
#   cpu_manufacturer
#   ssd
########################################
postchrt_prepare() {
	boot_mode="$(< BOOT_MODE)"

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
	while [[ -z "$interface" ]]; do
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
	while [[ "$ssd" != 'y' && "$ssd" != 'n' ]]; do
		read ssd
	done
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
	echo -e "127.0.1.1\t$hostname.localdomain\t$hostname" >> /etc/hosts

	# Network configuration
	echo "Configuring network..."
	case "$connection_type" in
	1)
		systemctl enable "dhcpcd@$interface.service"
		;;
	2)
		pacman -S --noconfirm iw wpa_supplicant dialog wpa_actiond
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
	'y')
		echo "An SSD is present in the system, enabling fstrim timer..."
		systemctl enable fstrim.timer
		;;
	'n')
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
	grub-mkconfig -o /boot/grub/grub.cfg

	cat << EOF
Installation complete!
You can now apply the optional system tweaks or simply reboot into your newly
installed system.
EOF
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

	cat << EOF
Tweaks applied successfully!
You can now reboot into your newly installed system.
EOF
}

case "$1" in
'pre-chroot')
	prechrt_prepare
	prechrt_pre_install
	prechrt_install
	prechrt_configure
	;;
'post-chroot')
	postchrt_prepare
	postchrt_configure
	;;
'tweaks')
	apply_tweaks
	;;
*)
	usage
	;;
esac
