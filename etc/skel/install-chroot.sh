#!/bin/bash

HOSTNAME=archbtw
USERNAME=toocels

systemctl enable NetworkManager

ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
echo "kok_IN UTF-8" >> /etc/locale.gen
echo 'LANG="C.UTF-8"' > /etc/locale.conf
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

grub-install --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
pacman -Sy

#bootctl install
#DRIVE=sda
#echo -e "timeout 3\ndefault arch.conf" >> /boot/loader/loader.conf
#echo -e "title   Arch Linux\nlinux   /vmlinuz-linux\ninitrd  /initramfs-linux.img\noptions root=/dev/${DRIVE}2 rw" >> /boot/loader/entries/arch.conf

#install yay
#git clone https://aur.archlinux.org/yay.git; cd yay; makepkg -si
#install synth-shell
#git clone --recursive https://github.com/andresgongora/synth-shell.git; cd synth-shell; ./setup.sh

#useradd -aG docker toocels
#sudo systemctl enable bluetoothd
#sudo systemctl enable gdm

