#!/bin/bash
# ===============================================================================
# PROJECT AEGIS: GENTOO MASTER TUI INSTALLER (v11 POST-MOUNT + BLEEDING EDGE)
# RYZE 5300U (ZEN 2) + LATEST STAGE3 + KDE PLASMA BETA (~AMD64)
# ===============================================================================

# 1. Dependency Check & Network
if ! command -v dialog &> /dev/null; then
    sudo emerge --ask=n --oneshot dev-util/dialog
fi

dialog --infobox 'Testing internet connection...' 5 40
while ! ping -c 1 gentoo.org &> /dev/null; do
  dialog --title 'Error' --msgbox 'No internet connection detected!\nPlease connect to Wi-Fi and run this script again.' 10 50
  clear; exit 1
done

# 2. PRE-FLIGHT CHECKS: Ensure User did the manual mounts correctly
if ! mountpoint -q /mnt/gentoo; then
    dialog --title 'MOUNT ERROR' --msgbox "CRITICAL: /mnt/gentoo is NOT mounted!\n\nPlease follow the manual mounting guide first." 10 60
    clear; exit 1
fi

if ! mountpoint -q /mnt/gentoo/boot/efi; then
    dialog --title 'MOUNT ERROR' --msgbox "CRITICAL: /mnt/gentoo/boot/efi is NOT mounted!\n\nPlease mount your EFI partition." 10 60
    clear; exit 1
fi

# 3. AUTO-DETECT PARTITIONS FOR FSTAB
ROOT_PART=$(findmnt -n -o SOURCE /mnt/gentoo)
BOOT_PART=$(findmnt -n -o SOURCE /mnt/gentoo/boot)
EFI_PART=$(findmnt -n -o SOURCE /mnt/gentoo/boot/efi)

dialog --title 'System Detection' --msgbox "Awesome! We auto-detected your manual mounts:\n\nROOT: $ROOT_PART\nBOOT: $BOOT_PART\nEFI:  $EFI_PART\n\nWe will use these to generate your fstab safely." 14 60

USER_NAME=$(dialog --title 'User' --inputbox 'Enter your new username (lowercase):' 8 60 3>&1 1>&2 2>&3)
clear

echo '==== [1/5] FETCHING THE ABSOLUTE LATEST STAGE 3 ===='
cd /mnt/gentoo
# Dynamically scrape the Gentoo server for today's exact release filename
STAGE3_URL=$(curl -s https://gentoo.osuosl.org/releases/amd64/autobuilds/latest-stage3-amd64-systemd.txt | grep -v "^#" | head -n 1 | awk '{print "https://gentoo.osuosl.org/releases/amd64/autobuilds/"$1}')

echo "Downloading Latest Stage3: $STAGE3_URL"
wget -O /mnt/gentoo/stage3.tar.xz "$STAGE3_URL"

if [ ! -s /mnt/gentoo/stage3.tar.xz ]; then
    echo "ERROR: Stage3 download failed. Aborting."
    exit 1
fi

echo '==== [2/5] UNPACKING GENTOO ===='
tar xpvf /mnt/gentoo/stage3.tar.xz -C /mnt/gentoo --xattrs-include='*.*' --numeric-owner
rm /mnt/gentoo/stage3.tar.xz

echo '==== [3/5] CONFIGURING MAKE.CONF (AMD + BLEEDING EDGE) ===='
mkdir -p /mnt/gentoo/var/tmp/portage
chmod 1777 /mnt/gentoo/var/tmp/portage

cat <<EOF > /mnt/gentoo/etc/portage/make.conf
# COMPILER FLAGS FOR RYZEN 5300U (ZEN 2 ARCHITECTURE)
COMMON_FLAGS="-O2 -pipe -march=znver2"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# UNLOCK BLEEDING EDGE (TESTING BRANCH) FOR LATEST KDE PLASMA BETA
ACCEPT_KEYWORDS="~amd64"

# HARDWARE & THREADS
PORTAGE_TMPDIR="/var/tmp/portage"
MAKEOPTS="-j6 -l6"
VIDEO_CARDS="amdgpu radeonsi"
GRUB_PLATFORMS="efi-64"

# BINARY ACCELERATION & USE FLAGS
FEATURES="getbinpkg buildpkg"
USE="wayland dbus pipewire pulseaudio vulkan sddm plasma networkmanager -X -gnome"
ACCEPT_LICENSE="*"
LC_MESSAGES=C.utf8
EOF

mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# Specific unlock for Zen Kernel (redundant but safe alongside ~amd64)
mkdir -p /mnt/gentoo/etc/portage/package.accept_keywords
echo "sys-kernel/zen-sources ~amd64" > /mnt/gentoo/etc/portage/package.accept_keywords/kernel

echo '==== [4/5] CHROOT PREPARATION ===='
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

echo '==== [5/5] ENTERING GENTOO CHROOT ===='
cat <<EOF > /mnt/gentoo/setup_chroot.sh
#!/bin/bash
source /etc/profile
export PORTAGE_TMPDIR="/var/tmp/portage"
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

# [AMD HARDWARE TRIGGER] Force amd-pstate support for Ryzen 5300U
sed -i 's/# CONFIG_X86_AMD_PSTATE is not set/CONFIG_X86_AMD_PSTATE=y/' /usr/share/genkernel/arch/x86_64/kernel-config
genkernel --tempdir=/var/tmp/genkernel all

# [DISK SAFETY] Sync kernel writes to physical SSD
echo ">> Flushing kernel buffers to disk..."
sync

echo ">> Creating 4GB Swapfile (Arch-Style)..."
dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress && chmod 600 /swapfile && mkswap /swapfile
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

echo ">> Installing LATEST KDE Plasma Beta (via ~amd64)..."
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
echo "Type: sudo umount -l /mnt/gentoo/dev{/shm,/pts,} && sudo umount -R /mnt/gentoo && reboot"
echo "================================================="
