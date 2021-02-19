#!/bin/bash

echo "Which keyboard model do you use?"
echo "1) pc104  2) pc105"
read choice
while [[ "$choice" != 1 && "$choice" != 2 ]]; do
  read choice
done

case "$choice" in
1)
  model=pc104
  ;;
2)
  model=pc105
  ;;
esac

localectl set-x11-keymap us "$model" altgr-intl terminate:ctrl_alt_bksp
