#!/bin/bash

DRIVE=${DRIVE:?Define DRIVE var with like sda or something bruh}

if [ "$EUID" -ne 0 ]
then
	echo "Please run as root."
	exit
fi

# wipe drive
wipefs -a /dev/$DRIVE
echo -e "g\nw\n" | fdisk /dev/$DRIVE

# create partitions
echo -e "n\n\n\n+1G\nw\n" | fdisk /dev/$DRIVE
echo -e "n\n\n\n\nw\n" | fdisk /dev/$DRIVE
echo -e "t\n1\n1\nw\n" | fdisk /dev/$DRIVE

# format partitions
mkfs.fat -F32 /dev/${DRIVE}1
mkfs.ext4 /dev/${DRIVE}2

mount /dev/${DRIVE}2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/${DRIVE}1 /mnt/boot/efi

pacman-key --init
pacman-key --populate

sed -i -e '/^\[core\]/,+2d' -e '/^\[extra\]/,+2d' /etc/pacman.conf
printf '\n[mePkg]\nSigLevel = Optional\nServer = file:///run/archiso/bootmnt/mePkg\n' | tee -a /etc/pacman.conf

pacstrap /mnt $(cat packages_pacman.x86_64)
genfstab -U /mnt >> /mnt/etc/fstab

cp *.sh /mnt/
cp *.x86_64 /mnt/

arch-chroot /mnt bash /install-chroot.sh
cp -r yay /mnt/home/toocels/
