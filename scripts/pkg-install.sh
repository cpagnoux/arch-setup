#!/bin/bash

gui=(
	'xorg'
	'i3'
	'dmenu'
	'lightdm'
	'lightdm-gtk-greeter'
	'numlockx'
)

base_apps=(
	'rxvt-unicode'
	'bash-completion'
	'nitrogen'
	'conky'
	'lsb-release'
	'dunst'
	'volumeicon'
	'alsa-utils'
	'scrot'
)

customization=(
	'archlinux-wallpaper'
	'arc-gtk-theme'
	'numix-gtk-theme'
)

cli_tools=(
	'fuseiso'
	'imagemagick'
	'lm_sensors'
	'openssh'
	'pacman-contrib'
	'pkgfile'
	'screenfetch'
	'smartmontools'
	'wget'
	'xclip'
	'xdg-user-dirs'
)

base_gui_apps=(
	'caja'
	'gvfs'
	'gvfs-mtp'
	'pluma'
	'eom'
	'atril'
	'engrampa'
)

accessories=(
	'keepassx2'
)

development=(
	'docker'
	'docker-compose'
	'gdb'
	'git'
	'nodejs'
	'npm'
	'yarn'
	'vim'
)

games=(
	'steam'
)

graphics=(
	'gimp'
	'inkscape'
	'shotwell'
)

internet=(
	'chromium'
	'pepper-flash'
	'filezilla'
	'hexchat'
	'transmission-gtk'
)

multimedia=(
	'audacious'
	'brasero'
	'vlc'
	'qt4'
)

office=(
	'libreoffice-fresh'
	'pandoc'
	'texlive-most'
)

system=(
	'gparted'
	'dosfstools'
	'exfat-utils'
	'ntfs-3g'
	'virtualbox'
	'virtualbox-host-modules-arch'
	'virtualbox-guest-iso'
)

wine=(
	'wine-staging'
	'wine_gecko'
	'wine-mono'
	'winetricks'
)

usage() {
	cat << EOF
Usage: $0 PACKAGE_SET

Package sets:
  full     install the complete set
  minimal  install a minimalist set
EOF
}

full_install() {
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

case "$1" in
'full')
	full_install
	;;
'minimal')
	minimal_install
	;;
*)
	usage
	;;
esac
