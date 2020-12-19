#!/bin/bash

# fetch up to date mirrorlist of selected country
# and optionally sort them
# auto detect all mirrors if no country is selected

if ! iroot askmirrors; then
    echo "skipping mirrors"
    exit
fi

echo "fetching mirrors"

if ! iroot automirrors; then
    COUNTRYCODE="$(iroot countrycode)"
    echo "fetching mirrors for $COUNTRYCODE"

    curl -s "https://archlinux.org/mirrorlist/?country=$COUNTRYCODE&protocol=http&protocol=https&ip_version=4&use_mirror_status=on" |
        grep -iE '(Server|generated)' |
        sed 's/^#Server /Server /g' >/tmp/mirrorlist

    cat /etc/pacman.d/mirrorlist >/tmp/oldmirrorlist

    if iroot sortmirrors; then
        head -20 /tmp/mirrorlist >/tmp/mirrorlist2
        rankmirrors -n 6 /tmp/mirrorlist2 >/tmp/topmirrors
        cat /tmp/topmirrors
        sleep 0.1
        cat /tmp/topmirrors >/etc/pacman.d/mirrorlist
        sleep 2
        clear
    else
        echo "" >/etc/pacman.d/mirrorlist
    fi

    cat /tmp/mirrorlist >>/etc/pacman.d/mirrorlist
    cat /tmp/oldmirrorlist >>/etc/pacman.d/mirrorlist
    mkdir /root/instantARCH/backup
    cat /etc/pacman.d/mirrorlist > /root/instantARCH/backup/mirrorlist
else
    echo "ranking mirrors"
    reflector --latest 40 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
fi

cat /etc/pacman.d/mirrorlist> /root/instantARCH/config/mirrorlistbackup
