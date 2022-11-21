#!/bin/bash

readonly packages=(
  chromium-widevine
  dropbox
  postman-bin
  rancher-k3d-bin
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
