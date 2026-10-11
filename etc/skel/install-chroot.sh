#!/bin/bash
# -----------------------------------------------------------------------------
# Project: Arch Linux Custom ISO & Offline Repository Builder
# File: etc/skel/install-chroot.sh
# Description: Post-installation chroot script executed within /mnt.
#              Configures system services, timezones, locales, hostname,
#              user accounts, sudoers policies, and generates Unified Kernel
#              Images (UKI) with UEFI boot entries.
#
# License: GNU General Public License v3.0 (GPL-3.0-or-later)
# SPDX-License-Identifier: GPL-3.0-or-later
# -----------------------------------------------------------------------------
set -e

# Target installation drive and identity parameters
DRIVE="${DRIVE:-sda}"
HOSTNAME="archbtw"
USERNAME="toocels"

echo "Configuring installed system inside chroot..."

# Enable essential systemd system daemons
echo "Enabling core system services..."
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable gdm

# Configure timezone and hardware clock
echo "Configuring timezone and localization..."
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

# Configure locale and console keymap
echo "en_IN UTF-8" >> /etc/locale.gen
echo "LANG=en_IN.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
locale-gen

# Configure system hostname and local name resolution
echo "Configuring network hostname..."
echo "${HOSTNAME}" > /etc/hostname
printf "\n127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t${HOSTNAME}\n" >> /etc/hosts

# Configure default terminal editor
export EDITOR=nano

# Configure sudo privileges for members of the wheel group
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# Prompt for root account password
echo "Enter password for root user:"
passwd

# Create primary administrative user and set credentials
useradd -mG wheel "${USERNAME}"
echo "Enter password for ${USERNAME} user:"
passwd "${USERNAME}"

# Add administrative user to docker group if docker package is installed
usermod -aG docker "${USERNAME}" 2>/dev/null || true

# PART_ROOT is inherited from install-live.sh (exported before arch-chroot invoked this script)

# Unified Kernel Image (UKI) configuration
echo "Configuring kernel cmdline for Unified Kernel Image..."
echo "root=UUID=$(blkid -s UUID -o value "${PART_ROOT}") rw quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0" > /etc/kernel/cmdline

echo "==================================================================="
echo "Note: In mkinitcpio presets (/etc/mkinitcpio.d/linux.preset):"
echo "  1. Comment 'default_image'"
echo "  2. Uncomment 'default_uki'"
echo "==================================================================="
read -r -p "Press Enter to open and review mkinitcpio preset..."
nano /etc/mkinitcpio.d/linux.preset

mkdir -p /efi/EFI/Linux
mkinitcpio -p linux

# Register the generated UKI into UEFI NVRAM using efibootmgr
echo "Registering UEFI boot entry..."
efibootmgr --create --disk "/dev/${DRIVE}" --part 1 --label "Arch Linux" --loader /EFI/Linux/arch-linux.efi --unicode

# Optional: Alternative GRUB Bootloader setup
# grub-install --efi-dir=/efi
# grub-mkconfig -o /boot/grub/grub.cfg

# Optional: Secure Boot setup via sbctl
# sbctl create-keys
# sbctl enroll-keys -m
# sbctl sign -s /efi/EFI/Linux/arch-linux.efi

echo "Post-installation chroot configuration completed successfully."
