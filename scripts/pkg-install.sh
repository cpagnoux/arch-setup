#!/bin/bash

readonly gui=(
	xorg
	i3
	dmenu
	lightdm
	lightdm-gtk-greeter
	numlockx
)

readonly base_apps=(
	kitty
	bash-completion
	zsh
	nitrogen
	dunst
	alsa-utils
	scrot
)

readonly customization=(
	archlinux-wallpaper
	adapta-gtk-theme
	arc-gtk-theme
	materia-gtk-theme
	elementary-icon-theme
	papirus-icon-theme
	adobe-source-code-pro-fonts
	adobe-source-sans-pro-fonts
	noto-fonts-emoji
	ttf-anonymous-pro
	ttf-font-awesome
	ttf-hack
	ttf-inconsolata
	ttf-roboto
)

readonly cli_tools=(
	cpupower
	fuseiso
	hdparm
	imagemagick
	lm_sensors
	lsb-release
	openssh
	pacman-contrib
	pkgfile
	playerctl
	pwgen
	redshift
	screenfetch
	smartmontools
	wget
	xclip
	xdg-user-dirs
)

readonly base_gui_apps=(
	nautilus
	gvfs
	gvfs-mtp
	gedit
	eog
	evince
	file-roller
	unrar
)

readonly accessories=(
	keepassxc
)

readonly development=(
	cmake
	docker
	docker-compose
	gdb
	git
	mariadb-clients
	php
	php-sqlite
	xdebug
	composer
	sqlite
	vim
	fzf
	ctags
)

readonly games=(
	lutris
	steam
)

readonly graphics=(
	gimp
	inkscape
	shotwell
	simple-scan
)

readonly internet=(
	chromium
	pepper-flash
	filezilla
	hexchat
	transmission-gtk
)

readonly multimedia=(
	audacious
	brasero
	vlc
)

readonly office=(
	libreoffice-fresh
	pandoc
	texlive-most
)

readonly system=(
	cups
	gparted
	dosfstools
	exfat-utils
	ntfs-3g
	virtualbox
	virtualbox-host-modules-arch
	virtualbox-guest-iso
)

readonly wine=(
	wine-staging
	giflib
	lib32-giflib
	libpng
	lib32-libpng
	libldap
	lib32-libldap
	gnutls
	lib32-gnutls
	mpg123
	lib32-mpg123
	openal
	lib32-openal
	v4l-utils
	lib32-v4l-utils
	libpulse
	lib32-libpulse
	libgpg-error
	lib32-libgpg-error
	alsa-plugins
	lib32-alsa-plugins
	alsa-lib
	lib32-alsa-lib
	libjpeg-turbo
	lib32-libjpeg-turbo
	sqlite
	lib32-sqlite
	libxcomposite
	lib32-libxcomposite
	libxinerama
	lib32-libxinerama
	ncurses
	lib32-ncurses
	opencl-icd-loader
	lib32-opencl-icd-loader
	libxslt
	lib32-libxslt
	libva
	lib32-libva
	gtk3
	lib32-gtk3
	gst-plugins-base-libs
	lib32-gst-plugins-base-libs
	vulkan-icd-loader
	lib32-vulkan-icd-loader
	cups
	samba
)

readonly driver_intel=(
	mesa
	lib32-mesa
	libva-intel-driver
	lib32-libva-intel-driver
	vulkan-icd-loader
	lib32-vulkan-icd-loader
	vulkan-intel
	lib32-vulkan-intel
)

readonly driver_nvidia=(
	linux-headers
	nvidia-dkms
	nvidia-utils
	lib32-nvidia-utils
	vulkan-icd-loader
	lib32-vulkan-icd-loader
	nvidia-settings
)

readonly driver_ati=(
	mesa
	lib32-mesa
	xf86-video-ati
	libva-mesa-driver
	lib32-libva-mesa-driver
)

usage() {
	cat <<EOF
Usage: $0 PACKAGE_SET

Package sets:
  normal         install the complete set
  minimal        install a minimalist set
  driver-intel   install the open source Intel driver
  driver-nvidia  install the proprietary NVIDIA driver
  driver-ati     install the open source ATI driver
EOF
}

normal_install() {
	pacman -S "${gui[@]}" \
		"${base_apps[@]}" \
		"${customization[@]}" \
		"${cli_tools[@]}" \
		"${base_gui_apps[@]}" \
		"${accessories[@]}" \
		"${development[@]}" \
		"${games[@]}" \
		"${graphics[@]}" \
		"${internet[@]}" \
		"${multimedia[@]}" \
		"${office[@]}" \
		"${system[@]}" \
		"${wine[@]}"
}

minimal_install() {
	pacman -S "${gui[@]}" \
		"${base_apps[@]}" \
		"${customization[@]}" \
		"${cli_tools[@]}" \
		"${base_gui_apps[@]}" \
		"${development[@]}" \
		"${internet[0]}" \
		"${internet[1]}"
}

driver_intel_install() {
	pacman -S "${driver_intel[@]}"
}

driver_nvidia_install() {
	pacman -S "${driver_nvidia[@]}"
}

driver_ati_install() {
	pacman -S "${driver_ati[@]}"
}

case "$1" in
normal)
	normal_install
	;;
minimal)
	minimal_install
	;;
driver-intel)
	driver_intel_install
	;;
driver-nvidia)
	driver_nvidia_install
	;;
driver-ati)
	driver_ati_install
	;;
*)
	usage
	;;
esac
