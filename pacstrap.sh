#!/bin.bash

sudo rm -r /pac-cache; sudo mkdir /pac-cache
sudo rm -r etc/skel/mePkg; sudo mkdir -p etc/skel/mePkg

# # # take snapshot of packages currently instlaled in host
comm -23 <(pacman -Qqe | sort) <(pacman -Qqm | sort) > cstm_repo_packages.x86_64
pacman -Qqe > etc/skel/cstm_repo_packages_yay.x86_64

# # # find all dependencies
rm tmp
for i in `cat cstm_repo_packages.x86_64`
do 
	pactree -l $i > tmp
	# pacman -Qi $i | grep "Depends On .*" -o | sed 's/Depends On .*: //' | sed 's/[[:space:]]\+/\n/g' >> tmp
	echo $i
done
cat cstm_repo_packages.x86_64 >> tmp
# sed -i 's/None//' tmp
# sed -i 's/>=[^ ]*$//' tmp
cat tmp | sort | uniq > dependencies.txt

exit 0
for i in `cat dependencies.txt`
do
	fn=$(sudo pacman -Sp $i | awk -F/ '{print $NF}')
	if ls /var/cache/pacman/pkg | grep $fn
	then
		sudo cp /var/cache/pacman/pkg/$fn /pac-cache
		sudo cp /var/cache/pacman/pkg/$fn.sig /pac-cache
	else
		sudo pacman -Sw --cachedir /pac-cache --noconfirm $i
	fi
done

sudo cp /pac-cache/* etc/skel/mePkg
sudo repo-add etc/skel/mePkg/mePkg.db.tar.gz etc/skel/mePkg/*.zst
# sudo chown $USER:$USER -R etc/skel/mePkg/