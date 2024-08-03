#!/bin/bash

set -e

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Set variables
IMAGE_NAME="ubuntu-jammy-minimal_4096_hwe.img"
IMAGE_SIZE=5000 # Size in MB
MOUNT_POINT="/mnt/ubuntu_jammy"
CHROOT_DIR="${MOUNT_POINT}"

# Create an empty image file
echo "Creating image file..."
dd if=/dev/zero of=${IMAGE_NAME} bs=1M count=${IMAGE_SIZE}

# Set up loopback device
LOOPDEV=$(losetup -f --show ${IMAGE_NAME})

# Create partition table
echo "Creating partition table..."
parted ${LOOPDEV} mklabel gpt
parted ${LOOPDEV} mkpart primary fat32 1 512M
parted ${LOOPDEV} set 1 esp on
parted ${LOOPDEV} mkpart primary ext4 512M 100%

# Set up loopback devices for partitions
LOOPDEV_BOOT="${LOOPDEV}p1"
LOOPDEV_ROOT="${LOOPDEV}p2"

# Format partitions
echo "Formatting partitions..."
mkfs.vfat -F32 ${LOOPDEV_BOOT}
mkfs.ext4 ${LOOPDEV_ROOT}

# Mount partitions
echo "Mounting partitions..."
mkdir -p ${MOUNT_POINT}
mount ${LOOPDEV_ROOT} ${MOUNT_POINT}
mkdir -p ${MOUNT_POINT}/boot/efi
mount ${LOOPDEV_BOOT} ${MOUNT_POINT}/boot/efi

# Bootstrap Ubuntu Jammy
echo "Bootstrapping Ubuntu Jammy..."
debootstrap --arch=amd64 jammy ${CHROOT_DIR} https://mirror.bizflycloud.vn/ubuntu/

# Mkdir system folder
mkdir -p ${MOUNT_POINT}/proc
mkdir -p ${MOUNT_POINT}/sys
mkdir -p ${MOUNT_POINT}/dev
mkdir -p ${MOUNT_POINT}/run
mkdir -p ${MOUNT_POINT}/tmp

# Mount necessary filesystems for chroot
echo "Mounting filesystems for chroot..."
# mount -t proc none ${CHROOT_DIR}/proc
# mount -t sysfs none ${CHROOT_DIR}/sys
# mount -o bind /dev ${CHROOT_DIR}/dev

echo "Chrooting and setting up the system..."
arch-chroot ${CHROOT_DIR} /bin/bash << EOF

# Remove old sources.list and create a new one with all repositories
rm -f /etc/apt/sources.list
echo "deb http://vn.archive.ubuntu.com/ubuntu/ jammy main restricted
deb http://vn.archive.ubuntu.com/ubuntu/ jammy-updates main restricted
deb http://vn.archive.ubuntu.com/ubuntu/ jammy universe
deb http://vn.archive.ubuntu.com/ubuntu/ jammy-updates universe
deb http://vn.archive.ubuntu.com/ubuntu/ jammy multiverse
deb http://vn.archive.ubuntu.com/ubuntu/ jammy-updates multiverse
deb http://vn.archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted
deb http://security.ubuntu.com/ubuntu/ jammy-security universe
deb http://security.ubuntu.com/ubuntu/ jammy-security multiverse" > /etc/apt/sources.list

# Set up fstab
echo "UUID=$(blkid -s UUID -o value ${LOOPDEV_BOOT}) /boot/efi vfat defaults 0 0" >> /etc/fstab
echo "UUID=$(blkid -s UUID -o value ${LOOPDEV_ROOT}) / ext4 errors=remount-ro 0 1" >> /etc/fstab

# Install necessary packages
apt-get update
apt-get upgrade -y
apt-get install -y linux-generic-hwe-22.04 linux-firmware grub-efi-amd64 network-manager htop openssh-client openssh-server vim tmux


# Set the hostname to "robot"
hostnamectl set-hostname robot
echo "robot" > /etc/hostname

# Update /etc/hosts
sed -i 's/127\.0\.1\.1.*/127.0.1.1 robot/' /etc/hosts

# Disable os-prober in GRUB configuration
echo "GRUB_DISABLE_OS_PROBER=true" >> /etc/default/grub

# Set up GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck
update-grub

# Set root password
echo "root:1" | chpasswd

# Enable and start NetworkManager
systemctl enable NetworkManager

# Create configuration to manage all devices
mkdir -p /etc/NetworkManager/conf.d/
echo "[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=no

[keyfile]
unmanaged-devices=none" > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

# Clean up
apt-get clean

EOF

# Generate UUID outside of chroot
UUID=$(cat /proc/sys/kernel/random/uuid)

# Create the content for the NetworkManager connection profile
NM_CONTENT="[connection]
id=default
uuid=${UUID}
type=ethernet
autoconnect=true

[ipv4]
method=auto

[ipv6]
method=ignore"

# Chroot and create a default NetworkManager connection profile
arch-chroot "${CHROOT_DIR}" /bin/bash << EOF
echo "${NM_CONTENT}" > /etc/NetworkManager/system-connections/default.nmconnection
chmod 600 /etc/NetworkManager/system-connections/default.nmconnection
EOF

# Unmount everything
echo "Unmounting and cleaning up..."
# umount ${CHROOT_DIR}/dev
# umount ${CHROOT_DIR}/sys
# umount ${CHROOT_DIR}/proc
umount ${MOUNT_POINT}/boot/efi
umount ${MOUNT_POINT}
# rmdir ${MOUNT_POINT}/boot/efi
# rmdir ${MOUNT_POINT}

# Clean up loopback devices
losetup -d ${LOOPDEV}

echo "Image created successfully: ${IMAGE_NAME}"

