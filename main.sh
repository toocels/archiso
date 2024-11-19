#!/bin/bash

set -e  # Exit immediately on error

# Function to handle the "packages" rule
build_packages() {
    echo "Starting pacstrap process..."

    TMP_FILE=$(mktemp)

    # Clean up and prepare directories
    sudo rm -rf /pac-cache etc/skel/mePkg
    sudo mkdir -p /pac-cache etc/skel/mePkg

    # Backup installed packages
    pacman -Qqe > etc/skel/packages.x86_64

    # Find all dependencies
    echo "Finding all dependencies..."
    for pkg in base linux linux-firmware nano networkmanager grub sudo base-devel git efibootmgr gnome-shell gnome-console gparted timeshift gdm firefox; do
        pactree -lu $pkg >> $TMP_FILE
    done
    sed -i 's/None//' $TMP_FILE
    sed -i 's/>=[^ ]*$//' $TMP_FILE
    sort -u $TMP_FILE -o $TMP_FILE

    # Download and copy package files
    echo "Downloading and copying packages..."
    CACHE=$(ls /var/cache/pacman/pkg)
    while read -r pkg; do
        fn=$(sudo pacman -Sp "$pkg" | awk -F/ '{print $NF}')
        echo $pkg
        if echo $CACHE | grep -qw "${fn}"; then
            sudo cp "/var/cache/pacman/pkg/${fn}" /pac-cache
            sudo cp "/var/cache/pacman/pkg/${fn}.sig" /pac-cache
        else
            sudo pacman -Sw --cachedir /pac-cache --noconfirm "$pkg"
        fi
    done < $TMP_FILE

    # Create the package repository
    echo "Creating package repository..."
    sudo cp /pac-cache/* etc/skel/mePkg
    sudo repo-add etc/skel/mePkg/mePkg.db.tar.gz etc/skel/mePkg/*.zst

    # Clean up
    rm -f $TMP_FILE
    echo "Pacstrap process completed."
}

# Function to handle the "archlive" rule
build_archlive() {
    echo "Creating archlive directory..."

    cp -r /usr/share/archiso/configs/releng/ archlive
    cp -r etc/* archlive/airootfs/etc/

    cat live_packages.x86_64 >> archlive/packages.x86_64

    # Remove autologin configuration
    rm -f archlive/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf

    # Configure sudoers for the wheel group
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > archlive/airootfs/etc/sudoers

    # Customize profiledef.sh
    sed -i 's/"archlinux/"cstm-archlinux/' archlive/profiledef.sh
    sed -i '/\["\/etc\/shadow"\]="0:0:400"/a \  ["\/etc\/gshadow"]="0:0:400"' archlive/profiledef.sh
    sed -i 's/%ARCHISO_UUID%/%ARCHISO_UUID% copytoram=no/' archlive/efiboot/loader/entries/01-archiso-x86_64-linux.conf

    # Disable timeout in loader configuration
    sed -i 's/on/off/' archlive/efiboot/loader/loader.conf

    echo "Archlive setup completed."
}

# Function to handle the "build" rule
build_iso() {
    echo "Building ISO..."

    sudo rm -rf /pac-iso
    sudo mkdir /pac-iso

    sudo cp -r ./ /pac-iso
    cd /pac-iso
    sudo mkarchiso -v archlive
    cd -
    cp -r /pac-iso/out ./
    sudo rm -rf /pac-iso

    echo "ISO build completed."
}

# Main script logic to replicate Makefile targets
case "$1" in
    packages)
        build_packages
        ;;
    archlive)
        build_archlive
        ;;
    build)
        build_iso
        ;;
    all)
        build_packages
        build_archlive
        build_iso
        ;;
    *)
        echo "Usage: $0 {packages|archlive|build|all}"
        exit 1
        ;;
esac
