#!/bin/bash

DRIVE=${DRIVE:?Please set the DRIVE environment variable (e.g., DRIVE=sda or DRIVE=nvme0n1)}

HOSTNAME=archbtw
USERNAME=toocels

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable gdm

ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
echo "en_IN UTF-8" >> /etc/locale.gen
echo "LANG=en_IN.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "${HOSTNAME}" > /etc/hostname
printf "\n127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t${HOSTNAME}" >> /etc/hosts
hwclock --systohc
locale-gen

export EDITOR=nano
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "Enter password for root user:"
passwd
useradd -mG wheel ${USERNAME}
echo "Enter password for ${USERNAME} user:"
passwd ${USERNAME}

usermod -aG docker toocels

# GRUB Bootloader setup (alternative)
#grub-install --efi-dir=/boot/efi
#grub-mkconfig -o /boot/grub/grub.cfg

# Unified Kernel Image (UKI) setup
#echo "root=UUID=$(blkid -s UUID -o value /dev/${DRIVE}2) rw quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0" > /etc/kernel/cmdline
#echo "Note: Comment default_image, uncomment default_uki, uncomment bitmap image, and change /efi to /boot/efi"
#read -r -p "Press Enter to edit mkinitcpio presets..."
#nano /etc/mkinitcpio.d/linux.preset
#mkdir -p /boot/efi/EFI/Linux
#mkinitcpio -p linux
#efibootmgr --create --disk /dev/${DRIVE}1 --part 1 --label "Arch Linux" --loader /EFI/Linux/arch-linux.efi --unicode

# AUR helper (yay) installation
#git clone https://aur.archlinux.org/yay.git; cd yay; makepkg -si

# sbctl Secure Boot setup
#sbctl create-keys
#sbctl enroll-keys -m
#sbctl sign -s /boot/efi/EFI/Linux/arch-linux.efi
