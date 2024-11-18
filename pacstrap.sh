#!/bin/bash

# Paths
PAC_CACHE="/pac-cache"
TMP_FILE=$(mktemp)

# Prepare directories
sudo rm -rf /pac-cache etc/skel/mePkg
sudo mkdir -p /pac-cache etc/skel/mePkg

# Backup installed packages
pacman -Qqe > etc/skel/packages.x86_64

# Find all dependencies
echo "Finding all dependencies..."
for pkg in base linux linux-firmware nano networkmanager grub sudo base-devel git efibootmgr gnome-shell gnome-console gparted timeshift gdm; do
    pactree -lu "$pkg" >> "$TMP_FILE"
done

sed -i 's/None//' "$TMP_FILE"
sed -i 's/>=[^ ]*$//' "$TMP_FILE"
sort -u "$TMP_FILE" -o dependencies.txt

# # Cache pacman package list
CACHE_CONTENT=$(ls /var/cache/pacman/pkg)

# Download and copy package files
echo "Downloading and copying packages..."
while read -r pkg; do
    fn=$(sudo pacman -Sp "$pkg" | awk -F/ '{print $NF}')
    if echo $CACHE_CONTENT | grep $fn -o; then
        sudo cp "/var/cache/pacman/pkg/$fn" /pac-cache
        sudo cp "/var/cache/pacman/pkg/$fn.sig" /pac-cache 2>/dev/null || true
    else
        sudo pacman -Sw --cachedir /pac-cache --noconfirm "$pkg"
    fi
done < dependencies.txt

# Create the package repository
echo "Creating package repository..."
sudo cp /pac-cache/* etc/skel/mePkg
sudo repo-add etc/skel/mePkg/mePkg.db.tar.gz etc/skel/mePkg/*.zst

# Clean up
rm "$TMP_FILE"
echo "Done."
