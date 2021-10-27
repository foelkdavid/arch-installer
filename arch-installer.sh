#!/bin/sh
#Checks if script is run as root
  ID=$(id -u)
  if [ "$ID" -ne "0" ];
  then
    echo "Command needs to be run as root."
    return 1
    exit
  fi
#
#
###################################
######### 1. PARTITIONING #########
###################################
#
#
#
#
  ##### NOTE: USED DRIVE MUST NOT HAVE MOUNTED PARTITIONS #####


  echo -e "\033[0;32m$(tput bold)---- Starting Partitioning ----$(tput sgr0)" &&
  sleep 1

  #displays drives over 1GiB to the User
    echo "Starting disk Partitioning"
    echo -e "Following disks are recommendet:"
    echo -e "\033[0;34m$(tput bold)"
    sudo sfdisk -l | grep "GiB" &&
    echo -e "$(tput sgr0)"

  #takes user input and removes existing partitions
    read -p "Please enter the path of the desired Disk for your new System: " DSK &&
    while true; do
        read -p "\033[0;32m$(tput bold)This will remove all existing partitions on "$DSK". Are you sure? [Yy/Nn]$(tput sgr0)" YN
        case $YN in
            [Yy]* ) dd if=/dev/zero of=$DSK bs=512 count=1 conv=notrunc; break; echo"done";;
            [Nn]* )  echo "you selected no"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    echo "REMOVING EXISTING FILESYSTEMS" &&
    sleep 3 &&

  #checks and prints used bootmode.
    if ls /sys/firmware/efi/efivars ; then
      BOOTMODE=UEFI
    else
      BOOTMODE=BIOS
    fi
    echo bootmode detected: $BOOTMODE &&

  #creating swap partition
    #get RAM size
    RAM=$(free -g | grep Mem: | awk '{print $2}') &&

    #setting swapsize variable to RAMsize+4G
    SWAPSIZE=$(expr $RAM + 4) &&
    echo "SWAPSIZE = "  $SWAPSIZE &&

  #creating efi, swap, root partition for UEFI systems; creating swap, root partition for BIOS systems
  if [ $BOOTMODE = UEFI ]; then printf "n\np\n \n \n+1G\nn\np\n \n \n+"$SWAPSIZE"G\nn\np\n \n \n \nw\n" | fdisk $DSK; else printf "n\np\n \n \n+"$SWAPSIZE"G\nn\np\n \n \n \nw\n" | fdisk $DSK; fi
  partprobe $DSK &&
  #getting paths of partitions
  PARTITION1=$(fdisk -l $DSK | grep $DSK | sed 1d | awk '{print $1}' | sed -n "1p") &&
  PARTITION2=$(fdisk -l $DSK | grep $DSK | sed 1d | awk '{print $1}' | sed -n "2p") &&
  if [ $BOOTMODE = UEFI ]; then PARTITION3=$(fdisk -l $DSK | grep $DSK | sed 1d | awk '{print $1}' | sed -n "3p"); else echo "No third Partition needet."; fi


  #declaring partition paths as variables
  if [ $BOOTMODE = UEFI ]; then
    EFIPART=$PARTITION1
    SWAPPART=$PARTITION2
    ROOTPART=$PARTITION3
  else
    EFIPART="NOT DEFINED"
    SWAPPART=$PARTITION1
    ROOTPART=$PARTITION2
  fi

  #filesystem creation
    #efi partition
    if [ $BOOTMODE = UEFI ]; then mkfs.fat -F32 $EFIPART; fi

    #swap partition
    mkswap $SWAPPART &&

    echo $ROOTPART

    #root partition
    mkfs.ext4 $ROOTPART &&

  #filesystem mounting / enabling swapspace
    #root partition
    mount $ROOTPART /mnt &&

    #swap partition
    swapon $SWAPPART &&

    #efi
    if [ $BOOTMODE = UEFI ]; then
      mkdir /mnt/efi
      mount $EFIPART /mnt/efi;
    fi

  echo -e "\033[0;32m$(tput bold)---- Finished Partitioning ----$(tput sgr0)" &&
  printf "\n\n"
  sleep 1




###################################
######### 2. PREPARATION ##########
###################################
#
#
#
#
  echo -e "\033[0;32m$(tput bold)---- Starting Preparation ----$(tput sgr0)" &&
  sleep 1

  echo "installing required packages to new system"
  pacstrap /mnt base linux linux-firmware networkmanager grub zsh man-db vim nano sudo &&

  echo "installing extended packages to new system"
  pacstrap /mnt neofetch 

  echo "generating fstab file:" &&
  genfstab -U /mnt >> /mnt/etc/fstab &&

  printf "\n\n" &&
  echo -e "\033[0;32m$(tput bold)---- Finished Preparation ----$(tput sgr0)" &&
  printf "\n\n"
#################################
######## 3. INSTALLATION ########
#################################
#
#
#
#
  echo -e "\033[0;32m$(tput bold)---- Starting Installation ----$(tput sgr0)" &&
  sleep 1


arch-chroot /mnt /bin/bash -- << EOCHROOT

        echo "setting timezone:" &&
        ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime &&
        echo "done." &&

        echo "syncing system time:" &&
        hwclock --systohc &&
        echo "done." &&

        echo "appending locales to locale.gen:" &&
        echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen &&
        echo "generating locales:" &&
        locale-gen &&
        echo "setting system locale:" &&
        echo "LANG=en_US.UTF-8" >> /etc/locale.conf &&
        echo "done!" &&

        echo "setting keymap" &&
        echo "KEYMAP=de-latin1" >> /etc/vconsole.conf &&
        echo "done" &&



        echo "enabling NetworkManager" &&
        systemctl enable NetworkManager &&




        echo "setting up sudo" &&
        echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers &&
        echo "%wheel ALL=(ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown" >> /etc/sudoers &&
        echo "done." &&

        echo "locking root user" &&
        passwd -l root &&
        echo "done" &&
        sleep 2 
EOCHROOT

      sleep 2 &&
      echo "setting hostname:" &&
      read -p "Please enter a valid Hostname : " CHN &&
      echo $CHN >> /mnt/etc/hostname &&
      echo "127.0.0.1 localhost" >> /mnt/etc/hosts &&
      echo "::1" >> /mnt/etc/hosts &&
      echo "127.0.1.1 $CHN.localdomain $CHN" >> /mnt/etc/hosts &&
      echo "done!" &&

      echo "creating new User" &&
      read -p "Please enter a valid username: " USRNME &&
      arch-chroot /mnt useradd -m $USRNME &&
      arch-chroot /mnt passwd $USRNME &&
      arch-chroot /mnt usermod -a -G wheel $USRNME &&

      echo "installing microcode" &&
      read -p "Please enter your CPU manufacturer:  [ amd | intel ]" SYSBRND && 
      pacstrap /mnt $SYSBRND-ucode &&
      echo "done!" &&


  if [ $BOOTMODE = UEFI ]; then
    echo "setting up grub for UEFI system:" &&
    pacstrap /mnt efibootmgr
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB &&
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &&
    echo "done";
  else
    echo "setting up grub for BIOS system:" &&
    arch-chroot /mnt grub-install --target=i386-pc $DSK &&
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &&
    echo "done";
  fi


  echo -e "\033[0;32m$(tput bold)---- Finished Installation ----$(tput sgr0)" &&
  printf "\n\n"
  echo -e "\033[0;32m$(tput bold)---- Enjoy your new System :) ----$(tput sgr0)" 
