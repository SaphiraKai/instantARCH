#!/bin/bash

# installs basic dependencies not specific to instantOS

source /root/instantARCH/moduleutils.sh

echo "installing additional system software"

pacman -Sy --noconfirm

while ! pacman -S xorg --noconfirm --needed; do
    dialog --msgbox "package installation failed \nplease reconnect to internet" 700 700
    iroot automirror && command -v reflector &&
        reflector --latest 40 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist

done

# the comments are used for parsing while building a live iso. Do not remove

# install begin

pacloop sudo \
    lightdm \
    bash \
    zsh \
    xterm \
    hdparm \
    systemd-swap \
    pulseaudio \
    granite \
    alsa-utils \
    usbutils \
    lightdm-gtk-greeter \
    noto-fonts \
    otf-ipafont \
    wqy-microhei \
    inetutils \
    xdg-desktop-portal-gtk \
    xorg-xinit \
    nitrogen \
    lshw \
    gxkb \
    ntfs-3g \
    gedit \
    ttf-liberation \
    ttf-joypixels \
    mpv \
    bc \
    gvfs-mtp \
    exfat-utils \
    unzip \
    engrampa \
    unrar \
    sushi \
    nano \
    exa \
    bat \
    p7zip \
    xdg-user-dirs-gtk \
    noto-fonts-emoji \
    xf86-input-evdev \
    xf86-input-synaptics \
    accountsservice \
    cups \
    samba \
    gvfs-smb \
    system-config-printer \
    gnome-font-viewer \
    trash-cli \
    fd \
    grub

# artix packages
if command -v sv; then
    echo "installing additional runit packages"
    pacloop lightdm-runit networkmanager-runit
fi

# auto install processor microcode
if uname -m | grep '^x'; then
    echo "installing microcode"
    if lscpu | grep -i 'name' | grep -i 'amd'; then
        echo "installing AMD microcode"
        pacloop amd-ucode
    elif lscpu | grep -i 'name' | grep -i 'intel'; then
        echo "installing Intel microcode"
        pacloop intel-ucode
    fi
fi
