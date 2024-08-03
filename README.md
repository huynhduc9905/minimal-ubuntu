# Minimal Ubuntu HWE Kernel Image Builder

This repository contains a bash script to create a minimal Ubuntu 22.04 (Jammy Jellyfish) image with the Hardware Enablement (HWE) kernel. The project uses GitHub Actions to automate the build process, making it easy to generate up-to-date images.

Kernel version (at Aug/2024): 6.5.0.44.44

UEFI boot

## Features

- Creates a 4GB image file with GPT partitioning
- Uses the Ubuntu 22.04 LTS (Jammy Jellyfish) base
- Installs the latest HWE kernel (linux-generic-hwe-22.04)
- Sets up GRUB for UEFI boot
- Configures NetworkManager for automatic network setup
- Includes basic utilities: htop, openssh-client, openssh-server, vim, tmux

## Requirements

- Root access (sudo)
- Ubuntu-based system (for building the image)
- debootstrap
- parted
- arch-chroot (from the arch-install-scripts package)

## Usage

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/minimal-ubuntu-hwe-image-builder.git
   cd minimal-ubuntu
   ```

2. Run the script as root:
   ```
   sudo ./jammy_bootstrap.sh
   ```

3. Wait for the script to complete. The resulting image will be named `ubuntu-jammy-minimal_hwe.img`.

## GitHub Actions (TODO)

This repository is set up to use GitHub Actions for automated builds. The workflow will:

1. Run on each push to the main branch
2. Build the Ubuntu image using the provided script
3. Upload the resulting image as an artifact

You can download the latest built image from the GitHub Actions page of this repository.

## Disclaimer

This script creates a minimal Ubuntu image and may not include all packages or configurations needed for your specific use case. Use at your own risk and make sure to review and understand the script before running it.
