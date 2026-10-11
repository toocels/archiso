#!/bin/bash
# -----------------------------------------------------------------------------
# Project: Arch Linux Custom ISO & Offline Repository Builder
# File: etc/skel/install-live.sh
# Description: Automated live installer script. Wipes the selected target drive,
#              creates GPT partition table (EFI and Root ext4), formats partitions,
#              configures offline mePkg repository mirror, pacstraps base system,
#              and hands off control to install-chroot.sh inside arch-chroot.
#
# License: GNU General Public License v3.0 (GPL-3.0-or-later)
# SPDX-License-Identifier: GPL-3.0-or-later
# -----------------------------------------------------------------------------
set -e

# Target drive configuration (defaults to sda if not explicitly set via environment)
DRIVE="${DRIVE:-sda}"

if [ "$EUID" -ne 0 ]; then
	echo "Error: Please run as root (or use sudo -E)." >&2
	exit 1
fi

# Anchor to this script's own directory so the relative package manifest
# reads below work regardless of the caller's current directory
cd "$(dirname "$(readlink -f "$0")")"

echo "Starting automated installation on /dev/${DRIVE}..."

# Step 1: Wipe all existing signatures and partition metadata from the target drive
echo "Wiping drive signatures on /dev/${DRIVE}..."
wipefs -a "/dev/${DRIVE}"

# Create a clean GPT table plus EFI (+1G) and root (remaining space) partitions
# in a single fdisk session, so the kernel only has to reload the partition
# table once at the final "w" instead of once per invocation. Doing it as 4
# separate fdisk calls let something (commonly udisks2 auto-probing the new
# partitions) grab the device between calls, making fdisk's own re-read
# ioctl report "Device or resource busy" even though the table write itself
# already succeeded - that spurious non-zero exit is what tripped `set -e`.
echo "Creating GPT table with EFI System and Root partitions..."
fdisk "/dev/${DRIVE}" <<-EOF || true
	g
	n


	+1G
	n



	t
	1
	1
	w
EOF

# Force the kernel/udev to pick up the new partition table before we touch
# any partition nodes below (fdisk's own reload above may have been rejected
# as busy; the table is on disk regardless, this just makes the nodes appear).
partprobe "/dev/${DRIVE}" || true
udevadm settle

# Determine partition naming based on disk type (e.g. nvme0n1p1 vs sda1)
if [[ "${DRIVE}" =~ [0-9]$ ]]; then
	PART_EFI="/dev/${DRIVE}p1"
	PART_ROOT="/dev/${DRIVE}p2"
else
	PART_EFI="/dev/${DRIVE}1"
	PART_ROOT="/dev/${DRIVE}2"
fi
# Exported so install-chroot.sh (run via arch-chroot below) can reuse it without recomputing
export PART_ROOT

# Step 3: Format partitions
echo "Formatting ${PART_EFI} as FAT32..."
mkfs.fat -F32 "${PART_EFI}"

echo "Formatting ${PART_ROOT} as ext4..."
mkfs.ext4 -F "${PART_ROOT}"

# Step 4: Mount root and EFI filesystems to /mnt
echo "Mounting target filesystems..."
mount "${PART_ROOT}" /mnt
mkdir -p /mnt/efi
mount "${PART_EFI}" /mnt/efi

# Step 5: Initialize Pacman keyring in the live environment
pacman-key --init
pacman-key --populate

# Step 6: Configure Pacman to consume the offline ISO repository (/run/archiso/bootmnt/mePkg)
echo "Configuring offline package repository from live medium..."
sed -i -e '/^\[core\]/,+2d' -e '/^\[extra\]/,+2d' /etc/pacman.conf
printf '\n[mePkg]\nSigLevel = Optional\nServer = file:///run/archiso/bootmnt/mePkg\n' | tee -a /etc/pacman.conf

# Step 7: Bootstrap base system packages onto /mnt from the local offline repository
echo "Installing base system packages via pacstrap..."
pacstrap /mnt $(cat packages_pacman.x86_64)

# Generate fstab using persistent filesystem UUIDs
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Copy installation helper scripts and manifests into the target chroot
cp *.sh /mnt/ 2>/dev/null || true
cp *.x86_64 /mnt/ 2>/dev/null || true

# Step 8: Enter chroot environment to execute final system configurations
echo "Entering chroot environment to finalize setup..."
arch-chroot /mnt bash /install-chroot.sh

echo "Live installation phase completed successfully."
