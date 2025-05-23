#!/bin/bash

DRIVE=sda

if [ "$EUID" -ne 0 ]
then
	echo "Please run as root."
	exit
fi

cp pacman.conf /etc/

# wipe drive
wipefs -a /dev/$DRIVE
echo -e "g\nw\n" | fdisk /dev/$DRIVE

# create partitions
echo -e "n\n\n\n+1G\nw\n" | fdisk /dev/$DRIVE
echo -e "n\n\n\n\nw\n" | fdisk /dev/$DRIVE
echo -e "t\n1\n1\nw\n" | fdisk /dev/$DRIVE

# format paritions
mkfs.fat -F32 /dev/${DRIVE}1
mkfs.ext4 /dev/${DRIVE}2

mount /dev/${DRIVE}2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/${DRIVE}1 /mnt/boot/efi

#pacstrap /mnt $(cat package_min.txt)
pacstrap /mnt $(cat packages_pacman.txt)
genfstab -U /mnt >> /mnt/etc/fstab

cp *.sh /mnt/

arch-chroot /mnt bash /install-chroot.sh

cp *.txt /mnt/home/toocels/
cp -r yay /mnt/home/toocels/
