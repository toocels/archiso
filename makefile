all:	
	make pacstrap
	make archlinux
	make build

archlinux:
	cp -r /usr/share/archiso/configs/releng/ archlive
	cp -r etc/* archlive/airootfs/etc/

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
	@echo "Starting pacstrap process..."
	# Define variables
	PAC_CACHE=/pac-cache
	TMP_FILE=$$(mktemp)
	CACHE_CONTENT=$$(ls /var/cache/pacman/pkg)

	# Clean up and prepare directories
	sudo rm -rf $${PAC_CACHE} etc/skel/mePkg
	sudo mkdir -p $${PAC_CACHE} etc/skel/mePkg

	# Backup installed packages
	pacman -Qqe > etc/skel/packages.x86_64

	# Find all dependencies
	echo "Finding all dependencies..."
	for pkg in base linux linux-firmware nano networkmanager grub sudo base-devel git efibootmgr gnome-shell gnome-console gparted timeshift gdm; do \
		pactree -lu $$pkg >> $${TMP_FILE}; \
	done
	sed -i 's/None//' $${TMP_FILE}
	sed -i 's/>=[^ ]*$$//' $${TMP_FILE}
	sort -u $${TMP_FILE} -o dependencies.txt

	# Download and copy package files
	echo "Downloading and copying packages..."
	while read -r pkg; do \
		fn=$$(sudo pacman -Sp $$pkg | awk -F/ '{print $$NF}'); \
		if echo $${CACHE_CONTENT} | grep -qw $$fn; then \
			sudo cp /var/cache/pacman/pkg/$$fn $${PAC_CACHE}; \
			sudo cp /var/cache/pacman/pkg/$$fn.sig $${PAC_CACHE} 2>/dev/null || true; \
		else \
			sudo pacman -Sw --cachedir $${PAC_CACHE} --noconfirm $$pkg; \
		fi; \
	done < dependencies.txt

	# Create the package repository
	echo "Creating package repository..."
	sudo cp $${PAC_CACHE}/* etc/skel/mePkg
	sudo repo-add etc/skel/mePkg/mePkg.db.tar.gz etc/skel/mePkg/*.zst

	# Clean up
	rm -f $${TMP_FILE}
	echo "Pacstrap process completed."
