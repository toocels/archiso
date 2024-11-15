all:	
	make pacstrap -i
	make archlinux
	make build
	make clean

archlinux:
	cp -r /usr/share/archiso/configs/releng/ archlive
	cp -r etc/* archlive/airootfs/etc/
	cat etc/skel/packages.x86_64 >> archlive/packages.x86_64

	read -p "Edit iso name, add gshadow like /etc/shadow"
	nano archlive/profiledef.sh # add gshadow like shadow

	rm archlive/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf
	echo "%wheel ALL=(ALL) NOPASSWD: ALL" > archlive/airootfs/etc/sudoers

	read -p "Add \`cow_spacesize=1G copytoram=no\` to options."
	nano archlive/efiboot/loader/entries/01-archiso-x86_64-linux.conf

	read -p "Tun off beep"
	nano archlive/efiboot/loader/loader.conf

	#nano archlive/grub/grub.cfg
	#nano archlive/syslinux/syslinux.cfg

build:
	sudo rm -r /mnt/*
	sudo cp -r ./* /mnt/
	cd /mnt; sudo mkarchiso -v archlive
	cp -r /mnt/out ./

pacstrap:
	@temp_dir=$$(sudo mktemp -d); \
	sudo chmod 755 $$temp_dir; \
	trap "sudo rm -rf '$$temp_dir'" EXIT; \
	mkdir /tmp/blankdb; \
	sudo pacman -Syw --cachedir $$temp_dir --dbpath /tmp/blankdb base linux linux-firmware nano networkmanager grub sudo base-devel git efibootmgr gnome --noconfirm; \
	mkdir -p etc/skel/mePkg; \
	cp -r $$temp_dir/* etc/skel/mePkg; \
	repo-add etc/skel/mePkg/mePkg.db.tar.gz etc/skel/mePkg/*.zst

clean:
	sudo rm -r archlinux
	sudo rm -r etc/skel/mePkg
