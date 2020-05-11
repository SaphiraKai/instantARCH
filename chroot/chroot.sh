#!/bin/bash

# enable lightdm greeter
if grep -q 'greeter-session' /etc/lightdm/lightdm.conf; then
    LASTSESSION="$(grep 'greeter-session' /etc/lightdm/lightdm.conf | tail -1)"
    sed -i "s/$LASTSESSION/greeter-session=lightdm-gtk-greeter/g"
else
    sed -i 's/^\[Seat:\*\]/\[Seat:\*\]\ngreeter-session=lightdm-gtk-greeter/g' /etc/lightdm.conf
fi

# fix gui not showing up
sed -i 's/^#logind-check-graphical=.*/logind-check-graphical=true/' /etc/lightdm/lightdm.conf

[ -e /etc/systemd/system ] || mkdir -p /etc/systemd/system
cp /root/instantARCH/data/instantarch.service /etc/systemd/system/instantarch.service

# needed to get internet to work
systemctl enable lightdm
systemctl enable NetworkManager
systemctl enable instantarch

systemctl start instantarch

# enable swap
systemctl enable systemd-swap
sed -i 's/^swapfc_enabled=.*/swapfc_enabled=1/' /etc/systemd/swap.conf

sed -i 's/# %wheel/%wheel/g' /etc/sudoers
