#!/bin/bash

set -e

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Set variables
IMAGE_NAME="ubuntu-jammy-minimal.img"
IMAGE_SIZE=2048 # Size in MB
MOUNT_POINT="/mnt/ubuntu_jammy"
CHROOT_DIR="${MOUNT_POINT}/chroot"

# Create an empty image file
dd if=/dev/zero of=${IMAGE_NAME} bs=1M count=${IMAGE_SIZE}

# Set up loopback device
LOOPDEV=$(losetup -f --show ${IMAGE_NAME})

# Create partition table
parted ${LOOPDEV} mklabel gpt
parted ${LOOPDEV} mkpart primary fat32 1 512M
parted ${LOOPDEV} set 1 esp on
parted ${LOOPDEV} mkpart primary ext4 512M 100%

# Set up loopback devices for partitions
LOOPDEV_BOOT="${LOOPDEV}p1"
LOOPDEV_ROOT="${LOOPDEV}p2"

# Format partitions
mkfs.vfat -F32 ${LOOPDEV_BOOT}
mkfs.ext4 ${LOOPDEV_ROOT}

# Mount partitions
mkdir -p ${MOUNT_POINT}
mount ${LOOPDEV_ROOT} ${MOUNT_POINT}
mkdir -p ${MOUNT_POINT}/boot/efi
mount ${LOOPDEV_BOOT} ${MOUNT_POINT}/boot/efi

# Bootstrap Ubuntu Jammy
debootstrap --arch=amd64 jammy ${CHROOT_DIR} http://archive.ubuntu.com/ubuntu/

# Mount necessary filesystems for chroot
mount -t proc none ${CHROOT_DIR}/proc
mount -t sysfs none ${CHROOT_DIR}/sys
mount -o bind /dev ${CHROOT_DIR}/dev

# Chroot and set up the system
chroot ${CHROOT_DIR} /bin/bash << EOF
# Set up fstab
echo "/dev/sda1 /boot/efi vfat defaults 0 0" >> /etc/fstab
echo "/dev/sda2 / ext4 errors=remount-ro 0 1" >> /etc/fstab

# Install necessary packages
apt-get update
apt-get install -y linux-generic grub-efi-amd64 ubuntu-standard

# Set up GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck
update-grub

# Set root password
echo "root:password" | chpasswd

# Clean up
apt-get clean
EOF

# Unmount everything
umount ${CHROOT_DIR}/dev
umount ${CHROOT_DIR}/sys
umount ${CHROOT_DIR}/proc
umount ${MOUNT_POINT}/boot/efi
umount ${MOUNT_POINT}

# Clean up loopback devices
losetup -d ${LOOPDEV}

echo "Image created successfully: ${IMAGE_NAME}"