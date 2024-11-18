# CSTM_REPO = base linux linux-firmware nano networkmanager grub sudo base-devel git efibootmgr
CSTM_REPO = $(shell cat cstm_repo_packages.x86_64 | tr '\n' ' ')

all:	
	make pacstrap -i
	make archlinux -i 
	make build -i

archlinux:
	cp -r /usr/share/archiso/configs/releng/ archlive
	cp -r etc/* archlive/airootfs/etc/

	#echo -e "gnome-shell\ngnome-terminal\nnetworkmanager" >> archlive/packages.x86_64
	cat live_packages.x86_64 >> archlive/packages.x86_64

	rm archlive/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf
	echo "%wheel ALL=(ALL) NOPASSWD: ALL" > archlive/airootfs/etc/sudoers

	sed -i 's/\"archlinux/\"cstm\-archlinux/' archlive/profiledef.sh
	sed -i '/\["\/etc\/shadow"\]="0:0:400"/a \  ["\/etc\/gshadow"]="0:0:400"' archlive/profiledef.sh
	sed -i 's/\%ARCHISO_UUID\%/\%ARCHISO_UUID\% copytoram=no/' archlive/efiboot/loader/entries/01-archiso-x86_64-linux.conf
	sed -i 's/on/off/' archlive/efiboot/loader/loader.conf

	#nano archlive/grub/grub.cfg
	#nano archlive/syslinux/syslinux.cfg

build:
	sudo rm -r /pac-build; sudo mkdir /pac-build
	sudo cp -r ./* /pac-build/
	cd /pac-build;	sudo mkarchiso -v archlive
	cp -r /pac-build/out ./

pacstrap:
	#sudo rm -r /pac-cache; sudo mkdir /pac-cache
	sudo rm -r etc/skel/mePkg; sudo mkdir -p etc/skel/mePkg
	
	# take snapshot of packages currently instlaled in host
	comm -23 <(pacman -Qqe | sort) <(pacman -Qqm | sort) > cstm_repo_packages.x86_64
	pacman -Qqe > etc/skel/cstm_repo_packages_yay.x86_64

	# find all dependencies
	for i in $(CSTM_REPO); do pacman -Qi $$i | grep "Depends On .*" -o | sed 's/Depends On .*: //' | sed 's/[[:space:]]\+/\n/g' >> depended_all_tmp.txt; done
	cat depended_all_tmp.txt | sort | uniq > depended_all_tmp2.txt
	sed -i 's/None//' depended_all_tmp2.txt
	sed -i 's/>=[^ ]*$//' depended_all_tmp2.txt
	cat depended_all_tmp2.txt | sort | uniq > depended_all.txt

	sudo pacman -Syw --cachedir /pac-cache --noconfirm $(shell cat depended_all.txt)

	#sudo cp /var/cache/pacman/pkg/* /pac-cache/
	#sudo cp /pac-cache/* etc/skel/mePkg
	#sudo repo-add etc/skel/mePkg/mePkg.db.tar.gz etc/skel/mePkg/*.zst
	#sudo chown $$USER:$$USER -R etc/skel/mePkg/
	#sudo rm -r /pac-cache
