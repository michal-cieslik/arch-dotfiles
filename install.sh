echo "";
echo "               .__              .__  .__ __    ";
echo "  _____   ____ |__| ____   _____|  | |__|  | __";
echo " /     \_/ ___\|  |/ __ \ /  ___/  | |  |  |/ /";
echo "|  Y Y  \  \___|  \  ___/ \___ \|  |_|  |    < ";
echo "|__|_|  /\___  >__|\___  >____  >____/__|__|_ \'";
echo "                                        ";
echo "                                                       ";

echo "     Easy-to-configure archlinux+i3 install script ";
echo "        for maximum comfort and minimum hassles ";
echo "";
echo "";

root_password="123"
user_password="123"

# boot partition size, in MB
boot_partition_size=500

# home partition size, in GB
home_partition_size=50

# checks wheter there is multilib repo enabled properly or not
IS_MULTILIB_REPO_DISABLED=$(cat /etc/pacman.conf | grep "#\[multilib\]" | wc -l)
if [ "$IS_MULTILIB_REPO_DISABLED" == "1" ]
then
    echo "You need to enable [multilib] repository inside /etc/pacman.conf file before running this script, aborting installation"
    exit -1
fi
echo "[multilib] repo correctly enabled, continuing"

# syncing system datetime
timedatectl set-ntp true

# getting latest mirrors for poland and germany
wget -O mirrorlist "https://www.archlinux.org/mirrorlist/?country=DE&country=PL&protocol=https&ip_version=4"
sed -ie 's/^.//g' ./mirrorlist
mv ./mirrorlist /etc/pacman.d/mirrorlist

# updating mirrors
pacman -Syyy

# adding fzf for making disk selection easier
pacman -S fzf --noconfirm

# open dialog for disk selection
selected_disk=$(sudo fdisk -l | grep 'Disk /dev/' | awk '{print $2,$3,$4}' | sed 's/,$//' | fzf | sed -e 's/\/dev\/\(.*\):/\1/' | awk '{print $1}')  

# formatting disk for UEFI install
echo "Formatting disk for UEFI install"
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/${selected_disk}
  g # gpt partitioning
  n # new partition
    # default: primary partition
    # default: partition 1
  +${boot_partition_size}M # mb on boot partition
    # default: yes if asked
  n # new partition
    # default: primary partition
    # default: partition 2
  +${home_partition_size}G # gb for home partition
    # default: yes if asked
  n # new partition
    # default: primary partition
    # default: partition 3
    # default: all space left of for root partition
    # default: yes if asked
  t # change partition type
  1 # selecting partition 1
  1 # selecting EFI partition type
  w # writing changes to disk
EOF

# outputting partition changes
fdisk -l /dev/${selected_disk}

# partition filesystem formatting
yes | mkfs.fat -F32 /dev/${selected_disk}1
yes | mkfs.ext4 /dev/${selected_disk}2
yes | mkfs.ext4 /dev/${selected_disk}3

# disk mount
mount /dev/${selected_disk}3 /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount /dev/${selected_disk}1 /mnt/boot
mount /dev/${selected_disk}2 /mnt/home

# pacstrap-ping desired disk
pacstrap /mnt base base-devel networkmanager rofi feh linux linux-headers \
os-prober efibootmgr ntfs-3g alacritty git zsh intel-ucode amd-ucode cpupower xf86-video-amdgpu vlc \
xorg-server xorg-xinit ttf-dejavu ttf-liberation ttf-inconsolata noto-fonts gucharmap \
chromium firefox geckodriver code xf86-video-intel zip unzip unrar docker \
pulseaudio pasystray pamixer python python-pip wget nginx \
openssh xorg-xrandr noto-fonts-emoji maim imagemagick xclip pinta light ranger \
ttf-roboto playerctl papirus-icon-theme hwloc p7zip hsetroot docker-compose \
nemo linux-firmware firewalld tree man glances inter-font darktable fzf \
mesa mesa-demos lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver \
mesa-vdpau lib32-mesa-vdpau zsh-syntax-highlighting xdotool cronie dunst entr \
xf86-video-nouveau xf86-video-vmware python-dbus httpie discord bind-tools \
virtualbox python-pywal lutris i3lock dbeaver ccache ttf-cascadia-code

# generating fstab
genfstab -U /mnt >> /mnt/etc/fstab

# enabled [multilib] repo on installed system
arch-chroot /mnt zsh -c 'echo "[multilib]" >> /etc/pacman.conf'
arch-chroot /mnt zsh -c 'echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf'

# updating repo status
arch-chroot /mnt pacman -Syyy

# setting right timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime

# enabling font presets for better font rendering
arch-chroot /mnt ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d
arch-chroot /mnt ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
arch-chroot /mnt ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d
arch-chroot /mnt zsh -c `echo 'export FREETYPE_PROPERTIES="truetype:interpreter-version=38"' >> /etc/profile.d/freetype2.sh`

# synchronizing timer
arch-chroot /mnt hwclock --systohc

# localizing system
arch-chroot /mnt sed -ie 's/#pl_PL.UTF-8 UTF-8/pl_PL.UTF-8 UTF-8/g' /etc/locale.gen
arch-chroot /mnt sed -ie 's/#pl_PL ISO-8859-2/pl_PL ISO-8859-2/g' /etc/locale.gen

# generating locale
arch-chroot /mnt locale-gen

# setting system language
arch-chroot /mnt echo "LANG=pl_PL.UTF-8" >> /mnt/etc/locale.conf

# setting machine name
arch-chroot /mnt echo "arch-pc" >> /mnt/etc/hostname

# setting hosts file
arch-chroot /mnt echo "127.0.0.1 localhost" >> /mnt/etc/hosts
arch-chroot /mnt echo "::1 localhost" >> /mnt/etc/hosts
arch-chroot /mnt echo "127.0.1.1 arch-pc.localdomain arch-pc" >> /mnt/etc/hosts

# making sudoers do sudo stuff without requiring password typing
arch-chroot /mnt sed -ie 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers

# make initframs
arch-chroot /mnt mkinitcpio -p linux

# setting root password
arch-chroot /mnt /bin/zsh -c 'echo "root:$root_password" | chpasswd'

# making user mcieslik
arch-chroot /mnt useradd -m -G wheel -s /bin/zsh mcieslik

# setting mcieslik password
arch-chroot /mnt /bin/zsh -c 'echo "mcieslik:$user_password" | chpasswd'

# installing systemd-boot
bootctl --path=/boot install

# configuring mcieslik boot entry
arch-chroot /mnt grep "UUID=" /etc/fstab | grep '/ ' | awk '{ print $1 }' | sed -e 's/UUID=//' > .root_disk_uuid
arch-chroot /mnt touch /boot/loader/entries/mcieslik.conf
arch-chroot /mnt echo "title mcieslik" >> /boot/loader/entries/mcieslik.conf
arch-chroot /mnt echo "linux /vmlinuz-linux" >> /boot/loader/entries/mcieslik.conf
arch-chroot /mnt echo "initrd /amd-ucode.img" >> /boot/loader/entries/mcieslik.conf
arch-chroot /mnt echo "initrd /initramfs-linux.img" >> /boot/loader/entries/mcieslik.conf
arch-chroot /mnt echo 'options root="UUID=root_disk_uuid" rw' >> /boot/loader/entries/mcieslik.conf
arch-chroot /mnt sed -ie "s/root_disk_uuid/$(cat .root_disk_uuid)/g" /boot/loader/entries/mcieslik.conf
arch-chroot /mnt rm .root_disk_uuid

# changing governor to performance
arch-chroot /mnt echo "governor='performance'" >> /mnt/etc/default/cpupower

# making services start at boot
arch-chroot /mnt systemctl enable cpupower.service
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable docker.service
arch-chroot /mnt systemctl enable cronie.service
arch-chroot /mnt systemctl enable sshd.service

# enabling and starting DNS resolver via systemd-resolved
arch-chroot /mnt systemctl enable systemd-resolved.service
arch-chroot /mnt systemctl start systemd-resolved.service

# making i3 default for startx for both root and mrcz
arch-chroot /mnt echo "exec i3" >> /mnt/root/.xinitrc
arch-chroot /mnt echo "exec i3" >> /mnt/home/mcieslik/.xinitrc

# installing yay
arch-chroot /mnt sudo -u mcieslik git clone https://aur.archlinux.org/yay.git /home/mcieslik/yay_tmp_install
arch-chroot /mnt sudo -u mcieslik /bin/zsh -c "cd /home/mcieslik/yay_tmp_install && yes | makepkg -si"
arch-chroot /mnt rm -rf /home/mcieslik/yay_tmp_install

# adding makepkg optimizations
arch-chroot /mnt sed -i -e 's/#MAKEFLAGS="-j2"/MAKEFLAGS=-j'$(nproc --ignore 1)'/' -e 's/-march=x86-64 -mtune=generic/-march=native/' -e 's/xz -c -z/xz -c -z -T '$(nproc --ignore 1)'/' /etc/makepkg.conf
arch-chroot /mnt sed -ie 's/!ccache/ccache/g' /etc/makepkg.conf

# installing various packages from AUR
arch-chroot /mnt sudo -u mcieslik yay -S i3-gaps --noconfirm
arch-chroot /mnt sudo -u mcieslik yay -S polybar --noconfirm
arch-chroot /mnt sudo -u mcieslik yay -S downgrade --noconfirm
arch-chroot /mnt sudo -u mcieslik yay -S corrupter-bin --noconfirm
arch-chroot /mnt sudo -u mcieslik yay -S ctop-bin --noconfirm
arch-chroot /mnt sudo -u mcieslik yay -S picom-tryone-git --noconfirm

# installing oh-my-zsh
arch-chroot /mnt sudo -u mcieslik curl -O https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh && chmod +x install.sh && RUNZSH=no ./install.sh && rm ./install.sh

# installing pi theme for zsh
arch-chroot /mnt sudo -u mcieslik /bin/zsh -c "wget -O /home/mcieslik/.oh-my-zsh/themes/pi.zsh-theme https://raw.githubusercontent.com/tobyjamesthomas/pi/master/pi.zsh-theme"

# installing fonts
arch-chroot /mnt sudo -u mcieslik mkdir /home/mcieslik/fonts_tmp_folder
arch-chroot /mnt sudo -u mcieslik sudo mkdir /usr/share/fonts/OTF/
# material icons
arch-chroot /mnt sudo -u mcieslik /bin/zsh -c "cd /home/mcieslik/fonts_tmp_folder && wget -O materialicons.zip https://github.com/google/material-design-icons/releases/download/3.0.1/material-design-icons-3.0.1.zip && unzip materialicons.zip"
arch-chroot /mnt sudo -u mcieslik /bin/zsh -c "sudo cp /home/mcieslik/fonts_tmp_folder/material-design-icons-3.0.1/iconfont/MaterialIcons-Regular.ttf /usr/share/fonts/TTF/"
# removing fonts tmp folder
arch-chroot /mnt sudo -u mcieslik rm -rf /home/mcieslik/fonts_tmp_folder

# installing config files
arch-chroot /mnt sudo -u mcieslik mkdir /home/mcieslik/GitHub
arch-chroot /mnt sudo -u mcieslik git clone https://github.com/ilbuonmarcio/mrczlnks /home/mcieslik/GitHub/mcieslik
arch-chroot /mnt sudo -u mcieslik /bin/zsh -c "cd /home/mcieslik/GitHub/mcieslik && chmod 700 /home/mcieslik/GitHub/mcieslik/install_configs.sh && ./install_configs.sh"

# create folder for screenshots
arch-chroot /mnt sudo -u mcieslik mkdir /home/mcieslik/Screenshots

# create pictures folder, secrets folder and moving default wallpaper
arch-chroot /mnt sudo -u mcieslik mkdir /home/mcieslik/Pictures/
arch-chroot /mnt sudo -u mcieslik mkdir /home/mcieslik/.secrets/
arch-chroot /mnt sudo -u mcieslik mkdir /home/mcieslik/Pictures/wallpapers/

# enable features on /etc/pacman.conf file
arch-chroot /mnt sed -ie 's/#UseSyslog/UseSyslog/g' /etc/pacman.conf
arch-chroot /mnt sed -ie 's/#Color/Color/g' /etc/pacman.conf
arch-chroot /mnt sed -ie 's/#TotalDownload/TotalDownload/g' /etc/pacman.conf
arch-chroot /mnt sed -ie 's/#VerbosePkgLists/VerbosePkgLists/g' /etc/pacman.conf

# enable firefox accelerated/webrender mode for quantum engine use
arch-chroot /mnt zsh -c 'echo "MOZ_ACCELERATED=1" >> /etc/environment'
arch-chroot /mnt zsh -c 'echo "MOZ_WEBRENDER=1" >> /etc/environment'

# unmounting all mounted partitions
umount -R /mnt

# syncing disks
sync

echo ""
echo "INSTALLATION COMPLETE! enjoy :)"
echo ""

sleep 3 && reboot