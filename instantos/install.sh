#!/bin/bash

# install all instantOS software
# and apply instantOS specific changes and workarounds

cd || exit 1

[ -e instantOS ] && rm -rf instantOS

while ! git clone --depth 1 https://github.com/instantOS/instantOS; do
    imenu -m "pull failed, please connect to the internet"
done

cd instantOS || exit 1

bash repo.sh
pacman -Sy --noconfirm

if command -v systemctl; then
    DEPENDPACKAGE="instantdepend"
else
    DEPENDPACKAGE="instantdepend-nosystemd"
fi

while ! pacman -S instantos "$DEPENDPACKAGE" --noconfirm; do
    if [ -e /usr/share/liveutils ] && ! grep -iq manjaro /etc/os-release; then
        imenu -m "package installation failed.
Please ensure you are connected to the internet"
    fi
    # fetch new mirrors if on arch
    if command -v reflector; then
        reflector --latest 40 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    else
        pacman-mirrors --geoip
    fi
    pacman -Sy --noconfirm

done

# don't install arch pamac on Manjaro
if ! grep -iq Manjaro /etc/os-release && ! command -v pamac; then
    echo "installing pamac"
    sudo pacman -S pamac-all --noconfirm
    sed -i 's/#EnableAUR/EnableAUR/g' /etc/pamac.conf
    sed -i 's/#CheckAURUpdates/CheckAURUpdates/g' /etc/pamac.conf
    echo 'EnableFlatpak' >> /etc/pamac.conf
fi

yes | pacman -S libxft-bgra
yes | pacman -S neofetch-git

cd ~/instantOS || exit 1

# disable plymouth on artix
if ! command -v systemctl || iroot noplymouth; then
    touch /opt/instantos/noplymouth
fi

bash rootinstall.sh

# change greeter appearance
[ -e /etc/lightdm ] || mkdir -p /etc/lightdm
cat /usr/share/instantdotfiles/lightdm-gtk-greeter.conf >/etc/lightdm/lightdm-gtk-greeter.conf

# fix grub on manjaro
if grep -iq 'manjaro' /etc/os-release; then
    update-grub
    mkinitcpio -P
else
    # custom grub theme
    sed -i 's~^#GRUB_THEME.*~GRUB_THEME=/usr/share/grub/themes/instantos/theme.txt~g' /etc/default/grub
    update-grub
fi
