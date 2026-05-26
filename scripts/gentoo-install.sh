#!/bin/bash
# ===============================================================================
# PROJECT AEGIS: GENTOO MASTER TUI INSTALLER (v9.0 GITHUB CLONE EDITION)
# PARAGON DEDICATED EFI + RYZE 5300U + 4GB SWAPFILE + WINDOWS 11 CANARY
# ===============================================================================

# Force unmount before formatting
umount /dev/nvme0n1p4 2>/dev/null
umount /dev/nvme0n1p5 2>/dev/null
umount /dev/nvme0n1p6 2>/dev/null

# Inside your installation script:
if [ -d "testing_gentoo" ]; then
    echo "Updating existing repository..."
    cd testing_gentoo && git pull
else
    echo "Cloning repository..."
    git clone https://github.com/kurtitamas85/testing_gentoo
    cd testing_gentoo
fi

# Because we are now booting from the Gentoo LiveGUI, we use 'emerge' instead of 'pacman'
if ! command -v dialog &> /dev/null; then
    echo "Installing Dialog interface..."
    emerge --ask=n --oneshot dev-util/dialog
fi

dialog --title 'Network Check' --msgbox 'Welcome to Aegis Gentoo Installer!\n\nSince you are using the Gentoo LiveGUI, please make sure you clicked the Wi-Fi icon in the bottom right corner of your screen and connected to the internet before continuing.' 10 60

dialog --infobox 'Testing internet connection...' 5 40
while ! ping -c 1 gentoo.org &> /dev/null; do
  dialog --title 'Error' --msgbox 'No internet connection detected!\n\nPlease click the network icon in the bottom right of your screen, connect to Wi-Fi, and run this script again.' 10 50
  clear; exit 1
done

dialog --title 'System Detection' --msgbox "Please ensure you have created your 3 dedicated partitions in Paragon Partition Manager:\n\n1. EFI (800MB, FAT32)\n2. BOOT (2GB, EXT4)\n3. ROOT (85-100GB, EXT4)\n\nWe will now ask for these partition names." 14 70

EFI_PART=$(dialog --title 'Partitions' --inputbox "Enter the NEW 800MB EFI partition (e.g., /dev/nvme0n1pX):" 10 60 3>&1 1>&2 2>&3)
BOOT_PART=$(dialog --title 'Partitions' --inputbox "Enter the NEW 2GB BOOT partition (e.g., /dev/nvme0n1pY):" 10 60 3>&1 1>&2 2>&3)
ROOT_PART=$(dialog --title 'Partitions' --inputbox 'Enter the NEW 85-100GB ROOT partition (e.g., /dev/nvme0n1pZ):' 10 60 3>&1 1>&2 2>&3)

dialog --title 'CRITICAL SECURITY CHECK' --yesno "We will now format:\nEFI: $EFI_PART\nBOOT: $BOOT_PART\nROOT: $ROOT_PART\n\nAre you sure these are the correct Gentoo partitions and NOT Windows?" 12 70
if [ $? -ne 0 ]; then clear; exit 1; fi

USER_NAME=$(dialog --title 'User' --inputbox 'Enter your new username (lowercase):' 8 60 3>&1 1>&2 2>&3)

clear
echo '==== [1/6] RE-FORMATTING PARAGON PARTITIONS SAFELY ===='
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -F "$BOOT_PART"
mkfs.ext4 -F "$ROOT_PART"

echo '==== [2/6] MOUNTING AND DOWNLOADING STAGE3 ===='
mount "$ROOT_PART" /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount "$BOOT_PART" /mnt/gentoo/boot
mkdir -p /mnt/gentoo/boot/efi

# Secure Mount for Windows Canary Compatibility (prevents BitLocker trigger)
mount -o umask=0077 "$EFI_PART" /mnt/gentoo/boot/efi

echo "Verifying disk space on ROOT partition:"
df -h /mnt/gentoo

echo "Fetching latest Gentoo Stage3 tarball (Systemd profile)..."
# Don't try to parse the index page if it's failing
# Use a variable for the base URL and the filename
STAGE3_URL="https://gentoo.osuosl.org/releases/amd64/autobuilds/20260524T170105Z/stage3-amd64-systemd-20260524T170105Z.tar.xz"

echo "Downloading Stage3..."
wget "$STAGE3_URL" -O /mnt/gentoo/stage3.tar.xz

if [ ! -f /mnt/gentoo/stage3.tar.xz ]; then
    echo "ERROR: Stage3 download failed. Aborting."
    exit 1
fi

echo '==== [3/6] UNPACKING GENTOO ===='
tar xpvf stage3.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3.tar.xz

echo '==== [4/6] CONFIGURING MAKE.CONF AND TMPDIR ===='
mkdir -p /mnt/gentoo/var/tmp/portage
# Ensure permissions are correct so Portage can write to disk
chmod 1777 /mnt/gentoo/var/tmp/portage

cat <<EOF > /mnt/gentoo/etc/portage/make.conf
COMMON_FLAGS="-O2 -pipe -march=znver2"
PORTAGE_TMPDIR="/var/tmp/portage"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
# Redirect portage temp to physical disk

# Safe multithreading to prevent OOM on 11.5GB Usable RAM
MAKEOPTS="-j6 -l6"
ACCEPT_LICENSE="*"

# Enable binary package acceleration
FEATURES="getbinpkg buildpkg"
VIDEO_CARDS="amdgpu radeonsi"
USE="wayland dbus pipewire pulseaudio vulkan sddm plasma networkmanager -X -gnome"
GRUB_PLATFORMS="efi-64"
LC_MESSAGES=C.utf8
EOF

mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# Unlocking the bleeding-edge testing branch for the Zen Kernel
mkdir -p /mnt/gentoo/etc/portage/package.accept_keywords
echo "sys-kernel/zen-sources ~amd64" > /mnt/gentoo/etc/portage/package.accept_keywords/kernel

echo '==== [5/6] CHROOT PREPARATION ===='
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

echo '==== [6/6] ENTERING GENTOO CHROOT ===='
cat <<EOF > /mnt/gentoo/setup_chroot.sh
#!/bin/bash
source /etc/profile
# Create physical tmp dir on disk
mkdir -p /var/tmp/portage
chown portage:portage /var/tmp/portage

echo ">> Syncing Live Portage Tree..."
emerge-webrsync
emerge --sync --quiet

echo ">> Selecting Profile (Systemd Plasma)..."
eselect profile set default/linux/amd64/23.0/desktop/plasma/systemd

echo ">> Setting Timezone & Locales..."
echo "Europe/Bucharest" > /etc/timezone
emerge --config sys-libs/timezone-data
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

echo ">> Building the Latest Zen Kernel RC..."
emerge sys-kernel/zen-sources sys-kernel/genkernel sys-kernel/linux-firmware
eselect kernel set 1
# Force amd-pstate support for Ryzen 5300U
sed -i 's/# CONFIG_X86_AMD_PSTATE is not set/CONFIG_X86_AMD_PSTATE=y/' /usr/share/genkernel/arch/x86_64/kernel-config
genkernel --tempdir=/var/tmp/genkernel all

echo ">> Creating 4GB Swapfile (Arch-Style)..."
dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress && chmod 600 /swapfile && mkswap /swapfile

# --- INSERT SYNC HERE ---
echo ">> Flushing swapfile buffers to disk..."
sync

echo ">> Generating Fstab..."
echo -e "UUID=\$(blkid -s UUID -o value $ROOT_PART) / ext4 defaults,noatime 0 1" > /etc/fstab
echo -e "UUID=\$(blkid -s UUID -o value $BOOT_PART) /boot ext4 defaults,noatime 0 2" >> /etc/fstab
echo -e "UUID=\$(blkid -s UUID -o value $EFI_PART) /boot/efi vfat umask=0077 0 2" >> /etc/fstab
echo -e "/swapfile none swap defaults 0 0" >> /etc/fstab

echo ">> Installing OS-Prober and NTFS-3G for Windows Detection..."
emerge -gK sys-boot/grub sys-boot/efibootmgr sys-boot/os-prober sys-fs/ntfs3g
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub

echo ">> Installing Bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Gentoo
grub-mkconfig -o /boot/grub/grub.cfg

echo ">> Installing Core Tools & Network..."
emerge -gK net-misc/networkmanager app-admin/sudo app-editors/nano app-shells/fish app-misc/fastfetch
systemctl enable NetworkManager

echo ">> Installing KDE Plasma (Binary Accelerated)..."
emerge -gK kde-plasma/plasma-meta kde-apps/dolphin
systemctl enable sddm

echo ">> Creating User..."
useradd -m -G wheel,audio,video,usb -s /usr/bin/fish $USER_NAME
echo "Enter password for $USER_NAME:" && passwd $USER_NAME
echo "Enter ROOT password:" && passwd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

chmod +x /mnt/gentoo/setup_chroot.sh
chroot /mnt/gentoo /bin/bash /setup_chroot.sh
rm /mnt/gentoo/setup_chroot.sh

echo "================================================="
echo "GENTOO DUAL-BOOT INSTALLATION COMPLETE!"
echo "Type: umount -l /mnt/gentoo/dev{/shm,/pts,} && umount -R /mnt/gentoo && reboot"
echo "================================================="
