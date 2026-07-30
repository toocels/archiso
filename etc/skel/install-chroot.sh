#!/bin/bash

HOSTNAME=archbtw
USERNAME=toocels

systemctl enable NetworkManager
systemctl enable bluetoothd
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

#echo "root=UUID=$(blkid -s UUID -o value /dev/sda2) rw rootflags=subvol=@ quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0" > /etc/kernel/cmdline
#read comment deafult_image, uncomment default_uki, also uncomment bitmap image
#nano /etc/mkinitcpio.d/linux.preset
#mkinitcpio -p linux
#efibootmgr --create --disk /dev/sda1 --part 1 --label "Arch Linux" --loader /EFI/Linux/arch-linux.efi --unicode

#grub-install
#grub-mkconfig -o /boot/grub/grub.cfg

#bootctl install
#DRIVE=sda
#echo -e "timeout 3\ndefault arch.conf" >> /boot/loader/loader.conf
#echo -e "title   Arch Linux\nlinux   /vmlinuz-linux\ninitrd  /initramfs-linux.img\noptions root=/dev/${DRIVE}2 rw" >> /boot/loader/entries/arch.conf

#install yay
#git clone https://aur.archlinux.org/yay.git; cd yay; makepkg -si
