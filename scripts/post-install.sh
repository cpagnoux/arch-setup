#!/bin/bash

# Enable services
systemctl enable \
  lightdm.service \
  smartd.service \
  docker.service

if [[ -f /usr/lib/systemd/system/bluetooth.service ]]; then
  systemctl enable bluetooth.service
fi

# Install nvm
export NVM_DIR="$HOME/.nvm" && (
  git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
  cd "$NVM_DIR"
  git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
) && \. "$NVM_DIR/nvm.sh"

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
