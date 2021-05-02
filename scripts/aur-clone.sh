#!/bin/bash

readonly packages=(
  chromium-widevine
  dropbox
  nerd-fonts-hack
  postman-bin
  robo3t-bin
  slack-desktop
  spotify
)

get_url() {
  local package="$1"

  echo "https://aur.archlinux.org/$package.git"
}

if [[ ! -d ~/aur ]]; then
  mkdir ~/aur
fi

cd ~/aur

for package in "${packages[@]}"; do
  url="$(get_url "$package")"
  git clone "$url"
done
