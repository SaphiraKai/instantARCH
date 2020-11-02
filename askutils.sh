#!/bin/bash

# User questions are seperated into functions to be reused in alternative installers
# like topinstall.sh

# check if the install session is GUI or cli

if [ -z "$INSTANTARCH" ]; then
    echo "defaulting instantarch location to /root/instantARCH"
    INSTANTARCH="/root/instantARCH"
fi

shopt -s expand_aliases
alias goback='backmenu && [ -n $GOINGBACK ] && return'

guimode() {
    if [ -e /opt/noguimode ]; then
        return 1
    fi

    if [ -n "$GUIMODE" ]; then
        return 0
    else
        return 1
    fi
}

# add installation info to summary
addsum() {
    SUMMARY="$SUMMARY
        $1: $(iroot $2)"
}

# set status wallpaper
wallstatus() {
    guimode && feh --bg-scale /usr/share/liveutils/$1.jpg &
}

artixinfo() {
    if command -v systemctl; then
        echo "regular arch based iso detected"
        return
    fi

    echo "You appear to be installing the non-systemd version of instantOS.
Support for non-systemd setups is experimental
Any issues should be solvable with manual intervention
Here's a list of things that do not work from the installer and how to work around them:
disk editor: set up partitions beforehand or use automatic partitioning
keyboard locale: set it manually after installation in the settings
systemd-swap (obviously)" | imenu -M

}

# ask for keyboard layout
asklayout() {
    cd "$INSTANTARCH"/data/lang/keyboard || return 1
    wallstatus worldmap

    LAYOUTLIST="$(ls)"
    if command -v localectl; then
        LAYOUTLIST="$LAYOUTLIST
$(localectl list-x11-keymap-layouts | sed 's/^/- /g')"
    fi

    NEWKEY="$(echo "$LAYOUTLIST" | imenu -l 'Select keyboard layout ')"

    if grep -q '^-' <<<"$NEWKEY"; then
        iroot otherkey "$NEWKEY"
        NEWKEY="$(echo "$NEWKEY" | sed 's/- //g')"
        echo "
$NEWKEY" >/root/instantARCH/data/lang/keyboard/other
    fi

    # option to cancel the installer
    if [ "${NEWKEY}" = "forcequit" ]; then
        exit 1
    fi

    if iroot otherkey; then
        iroot keyboard other
        NEWKEY="other"
    else
        iroot keyboard "$NEWKEY"
    fi
    BACKASK="layout"
}

# ask for default locale
asklocale() {
    cd "$INSTANTARCH"/data/lang/locale || return 1
    while [ -z "$NEWLOCALE" ]; do
        NEWLOCALE="$(ls | imenu -l 'Select language> ')"
    done
    iroot locale "$NEWLOCALE"
    BACKASK="locale"

}

# menu that allows choosing a partition and put it in stdout
choosepart() {
    unset RETURNPART
    while [ -z "$RETURNPART" ]; do
        fdisk -l | grep '^/dev' | sed 's/\*/ b /g' | imenu -l "$1" | grep -o '^[^ ]*' >/tmp/diskchoice
        RETURNPART="$(cat /tmp/diskchoice)"
        if ! [ -e "$RETURNPART" ]; then
            imenu -m "$RETURNPART does not exist" &>/dev/null
            unset RETURNPART
        fi

        for i in /root/instantARCH/config/part*; do
            if grep "^$RETURNPART$" "$i"; then
                echo "partition $RETURNPART already taken"
                imenu -m "partition $RETURNPART is already selected for $i"
                CANCELOPTION="$(echo '> alternative options
select another partition
cancel partition selection' | imenu -l ' ')"
                if grep -q 'cancel' <<<"$CANCELOPTION"; then
                    touch /tmp/loopaskdisk
                    rm /tmp/homecancel
                    iroot r manualpartitioning
                    exit 1
                fi
                unset RETURNPART
            fi
        done

    done
    echo "$RETURNPART"
}

# ask for region with region/city
askregion() {
    cd /usr/share/zoneinfo || return 1
    while [ -z "$REGION" ]; do
        REGION=$(ls | imenu -l "select region ")
    done

    if [ -d "$REGION" ]; then
        cd "$REGION" || return 1
        while [ -z "$CITY" ]; do
            CITY=$(ls | imenu -l "select the City nearest to you ")
        done
    fi

    iroot region "$REGION"
    [ -n "$CITY" ] && iroot city "$CITY"
    BACKASK="region"

}

# choose between different nvidia drivers
askdrivers() {
    if lspci | grep -iq 'nvidia'; then
        echo "nvidia card detected"
        iroot hasnvidia 1
        while [ -z "$DRIVERCHOICE" ]; do
            DRIVERCHOICE="$(echo 'nvidia proprietary (recommended)
nvidia-dkms (try if proprietary does not work)
nouveau open source
install without graphics drivers (not recommended)' | imenu -l 'select graphics drivers')"

            if grep -q "without" <<<"$DRIVERCHOICE"; then
                if ! echo "are you sure you do not want to install graphics drivers?
This could prevent the system from booting" | imenu -C; then
                    unset DRIVERCHOICE
                fi
            fi

        done

        if grep -qi "dkms" <<<"$DRIVERCHOICE"; then
            iroot graphics "dkms"
        elif grep -qi "nvidia" <<<"$DRIVERCHOICE"; then
            iroot graphics "nvidia"
        elif grep -qi "open" <<<"$DRIVERCHOICE"; then
            iroot graphics "open"
        elif [ -z "$DRIVERCHOICE" ]; then
            iroot graphics "nodriver"
        fi

    else
        echo "no nvidia card detected"
    fi

    BACKASK="drivers"

}

# offer to choose mirror country
askmirrors() {
    iroot askmirrors 1
    curl -s 'https://www.archlinux.org/mirrorlist/' | grep -i '<option value' >/tmp/mirrors.html
    grep -v '>All<' /tmp/mirrors.html | sed 's/.*<option value=".*">\(.*\)<\/option>.*/\1/g' |
        sed -e "1iauto detect mirrors (not recommended for speed)" |
        imenu -l "choose mirror location" >/tmp/mirrorselect
    if ! grep -q 'auto detect' </tmp/mirrorselect; then
        grep ">$(cat /tmp/mirrorselect)<" /tmp/mirrors.html | grep -o '".*"' | grep -o '[^"]*' | iroot i countrycode
        if echo '> manually sorting mirrors may take a long time
use arch ranking score (recommended)
sort all mirrors by speed' | imenu -l 'choose mirror settings' | grep -q 'speed'; then
            iroot sortmirrors 1
        fi
    else
        iroot automirrors 1
    fi
    BACKASK="mirrors"
}

startpartchoice() {
    STARTCHOICE="$(echo 'edit partitions
choose partitions' | imenu -l)"

    case "$STARTCHOICE" in
    edit*)
        export ASKTASK="editparts"
        ;;
    choose*)
        export ASKTASK="root"
        ;;
    esac
    export BACKASK="startpartchoice"
}

# choose root partition for programs etc
chooseroot() {
    while [ -z "$ROOTCONFIRM" ]; do
        PARTROOT="$(choosepart 'choose root partition (required) ')"
        if imenu -c "This will erase all data on that partition. Continue?"; then
            ROOTCONFIRM="true"
            echo "instantOS will be installed on $PARTROOT"
        fi
        echo "$PARTROOT" | iroot i partroot
    done
    BACKASK="root"
    ASKTASK="home"
}

# cfdisk wrapper to modify partition table during installation
editparts() {
    echo 'instantOS requires the following paritions: 
 - a root partition, all data on it will be erased
 - an optional home partition.
    If not specified, the same partition as root will be used. 
    Gives you the option to keep existing data on the partition
 - an optional swap partition. 
    If not specified a swap file will be used. 
The Bootloader requires

 - an EFI partition on uefi systems
 - a disk to install it to on legacy-bios systems
' | imenu -M

    EDITDISK="$(fdisk -l | grep -i '^Disk /.*:' | imenu -l 'choose disk to edit> ' | grep -o '/dev/[^:]*')"
    echo "editing disk $EDITDISK"
    if guimode; then
        if command -v st; then
            st -e bash -c "cfdisk $EDITDISK"
        elif command -v st; then
            st -e bash -c "cfdisk $EDITDISK"
        else
            xterm -e bash -c "cfdisk $EDITDISK"
        fi
    else
        cfdisk "$EDITDISK"
    fi

    iroot disk "$EDITDISK"
    startchoice
}

# choose home partition, allow using existing content or reformatting
choosehome() {
    if ! imenu -c "do you want to use a seperate home partition?"; then
        return
    fi


    HOMEPART="$(choosepart 'choose home partition >')"
    case "$(echo 'keep current home data
erase partition to start fresh' | imenu -l)" in
    keep*)
        echo "keeping data"

        if imenu -c "do not overwrite dotfiles? ( warning, this can impact functionality )"
        then
            iroot keepdotfiles 1
        fi

        ;;
    erase*)
        echo "erasing"
        iroot erasehome 1
        ;;
    esac
    iroot parthome "$HOMEPART"
    echo "$HOMEPART" >/root/instantARCH/config/parthome
    export BACKASK="home"
    export ASKTASK="swap"

}

# ask for user details
askuser() {
    while [ -z "$NEWUSER" ]; do
        wallstatus user
        NEWUSER="$(imenu -i 'set username')"

        # validate input as a unix name
        if ! grep -Eq '^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$' <<<"$NEWUSER"; then
            imenu -e "invalid username, usernames must not contain spaces or special symbols and start with a lowercase letter"
            unset NEWUSER
        fi
    done

    while ! [ "$NEWPASS" = "$NEWPASS2" ] || [ -z "$NEWPASS" ]; do
        NEWPASS="$(imenu -P 'set password')"
        NEWPASS2="$(imenu -P 'confirm password')"
        if ! [ "$NEWPASS" = "$NEWPASS2" ]; then
            echo "the confirmation password doesn't match.
Please enter a new password" | imenu -M
        fi
    done

    iroot user "$NEWUSER"
    iroot password "$NEWPASS"

    BACKASK="user"

}

# ask about which hypervisor is used
askvm() {
    if imvirt | grep -iq 'physical'; then
        echo "system does not appear to be a virtual machine"
        return
    fi

    while [ -z "$VIRTCONFIRM" ]; do
        if ! imenu -c "is this system a virtual machine?"; then
            if echo "Are you sure it's not?
giving the wrong answer here might greatly decrease performance. " | imenu -C; then
                BACKASK="vm"
                return
            fi
        else
            VIRTCONFIRM="true"
        fi
    done
    iroot isvm 1

    echo "virtualbox
kvm/qemu
other" | imenu -l "which hypervisor is being used?" >/tmp/vmtype

    HYPERVISOR="$(cat /tmp/vmtype)"
    case "$HYPERVISOR" in
    kvm*)
        if grep 'vendor' /proc/cpuinfo | grep -iq 'AMD'; then
            echo "WARNING:
        kvm/QEMU on AMD is not meant for desktop use and
        is lacking some graphics features.
        This installation will work, but some features will have to be disabled and
        others might not perform well. 
        It is highly recommended to use Virtualbox instead." | imenu -M
            iroot kvm 1
            if lshw -c video | grep -iq 'qxl'; then
                echo "WARNING:
QXL graphics detected
These may trigger a severe Xorg memory leak on kvm/QEMU on AMD,
leading to degraded video and input performance,
please switch your video card to either virtio or passthrough
until this is fixed" | imenu -M
            fi
        fi
        ;;
    virtualbox)
        iroot virtualbox 1
        if imenu -c "would you like to install virtualbox guest additions?"; then
            iroot guestadditions 1
        fi
        ;;
    other)
        iroot othervm 1
        echo "selecting other"
        ;;
    esac
    export BACKASK="vm"

}

confirmask() {
    SUMMARY="Installation Summary:"

    addsum "Username" "user"
    addsum "Locale" "locale"
    addsum "Region" "region"
    addsum "Subregion" "city"

    if iroot otherkey; then
        addsum "Keyboard layout" "otherkey"
    else
        addsum "Keyboard layout" "keyboard"
    fi

    # todo: custom summary for manual partitioning
    addsum "Target install drive" "disk"

    addsum "Hostname" "hostname"

    if efibootmgr; then
        SUMMARY="$SUMMARY
GRUB: UEFI"
    else
        SUMMARY="$SUMMARY
GRUB: BIOS"
    fi

    SUMMARY="$SUMMARY
Should installation proceed with these parameters?"

    echo "summary:
$SUMMARY"

    if imenu -C <<<"$SUMMARY"; then
        iroot confirm 1
        export ASKCONFIRM="true"
    else
        unset CITY
        unset REGION
        unset DISK
        unset NEWKEY
        unset NEWLOCALE
        unset NEWPASS2
        unset NEWPASS
        unset NEWHOSTNAME
        unset NEWUSER
    fi
}
