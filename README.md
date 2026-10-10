# Arch Linux Custom ISO & Offline Repository Builder

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Arch%20Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

A modular automation suite designed to generate customized, bootable Arch Linux live ISO installation media with bundled offline package repositories and automated installation workflows.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Project Architecture](#project-architecture)
  - [Build Pipeline](#build-pipeline)
  - [Directory Layout](#directory-layout)
- [Prerequisites](#prerequisites)
- [Build Instructions](#build-instructions)
  - [Step 1: Workspace Initialization](#step-1-workspace-initialization)
  - [Step 2: Offline Package Assembly](#step-2-offline-package-assembly)
  - [Step 3: Archiso Profile Customization](#step-3-archiso-profile-customization)
  - [Step 4: ISO Compilation and Repository Injection](#step-4-iso-compilation-and-repository-injection)
- [How-To Operations Guide](#how-to-operations-guide)
  - [How to Test the ISO in a Virtual Machine (QEMU/KVM)](#how-to-test-the-iso-in-a-virtual-machine-qemukvm)
  - [How to Write the ISO to a USB Drive](#how-to-write-the-iso-to-a-usb-drive)
  - [How to Deploy to Target Hardware (Offline Installation)](#how-to-deploy-to-target-hardware-offline-installation)
  - [How to Customize Live Environment Packages](#how-to-customize-live-environment-packages)
  - [How to Manage Target Packages in packages_collection.x86_64](#how-to-manage-target-packages-in-packages_collectionx86_64)
  - [How to Customize Default Credentials and Users](#how-to-customize-default-credentials-and-users)
  - [How to Perform a Clean Rebuild](#how-to-perform-a-clean-rebuild)
  - [How to Troubleshoot Build Issues](#how-to-troubleshoot-build-issues)
- [Configuration Reference](#configuration-reference)
- [License](#license)

---

## Overview

Deploying Arch Linux across physical workstations or virtual machines in air-gapped, bandwidth-restricted, or reproducible environments requires an installation medium containing all required dependencies locally.

This project automates the compilation of a custom offline repository directly from a declarative package collection manifest ([`etc/skel/packages_collection.x86_64`](etc/skel/packages_collection.x86_64)), recursively resolves full dependency graphs using `pactree`, indexes them into an offline Pacman repository database (`mePkg`), builds a customized `archiso` live environment featuring GNOME utilities, and injects the offline repository into the resulting ISO image using `xorriso`.

---

## Key Features

- **Declarative Package Manifest**: Reads packages from [`etc/skel/packages_collection.x86_64`](etc/skel/packages_collection.x86_64) rather than depending on host-installed system packages, ensuring consistent and reproducible builds.
- **Automated Recursive Dependency Resolution**: Uses `pactree` to resolve complete official dependency trees into `deps.txt` so that no runtime network connectivity is required during target system deployment.
- **Self-Contained Offline Repository (`mePkg`)**: Downloads `.pkg.tar.zst` packages and generates a Pacman database index (`repo-add mePkg/mePkg.db.tar.gz`) mapped directly into the root of the ISO image (`/mePkg`).
- **Customized Live Environment**: Bundles administrative utilities (GNOME Terminal, Disks, GParted, TestDisk, Nmap, Fastfetch, `sbctl`, and Btrfs/LVM toolchains) into the live boot medium.
- **Resource-Constrained Compilation**: Uses `systemd-run --scope -p CPUQuota` to throttle CPU usage during intensive `mkarchiso` squashfs compression, keeping host systems responsive.
- **Direct ISO Layer Injection**: Leverages `xorriso` to graft the offline package repository directly into the built ISO structure without requiring a full live squashfs rebuild.
- **Automated Target Provisioning**: Ships automated installation scripts ([`install-live.sh`](etc/skel/install-live.sh) and [`install-chroot.sh`](etc/skel/install-chroot.sh)) to automate GPT disk partitioning, filesystem formatting, offline pacstrapping from the local repository, and initial system configuration.
- **Free and Open-Source Software**: Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).

---

## Project Architecture

### Build Pipeline

The build workflow is structured into four sequential, decoupled stages:

```
[1_init]   --> Prepares dedicated /iso workspace directory
    |
[2_pkgs]   --> Reads etc/skel/packages_collection.x86_64, resolves deps, builds mePkg.db
    |
[3_releng] --> Configures archlive profile, overlays custom /etc & packages_live.x86_64
    |
[4_build]  --> Compiles live ISO (mkarchiso) & injects offline repository (xorriso)
```

### Directory Layout

```
.
├── 1_init                         # Stage 1: Workspace setup script (/iso creation)
├── 2_pkgs                         # Stage 2: Offline package resolution and mePkg repository builder
├── 3_releng                       # Stage 3: Archiso profile configuration and overlay staging
├── 4_build                        # Stage 4: ISO compilation and xorriso repository injection
├── packages_live.x86_64           # Package manifest for live bootable ISO environment
├── etc/                           # Custom configuration overlays for live and installed systems
│   ├── group                      # Pre-configured groups
│   ├── gshadow                    # Pre-configured group shadow database
│   ├── passwd                     # Pre-configured user accounts
│   ├── shadow                     # Pre-configured user shadow database
│   └── skel/                      # User skeleton directory deployed to live/installed system
│       ├── .bashrc                # Shell startup configuration and aliases (e.g. gui launcher)
│       ├── install-live.sh        # Automated partitioning and offline pacstrap script
│       ├── install-chroot.sh      # Automated post-installation chroot configuration script
│       └── packages_collection.x86_64 # Declarative package manifest for target installation
├── LICENSE                        # GNU General Public License v3.0
└── README.md                      # Project documentation
```

---

## Prerequisites

Before executing the build pipeline, ensure your host environment meets the following requirements:

- **Host Operating System**: Arch Linux (or Arch-based distribution)
- **Privileges**: Root or `sudo` access
- **Disk Space**: At least 25 GB of free space under `/` (for squashfs layers and package caches)
- **Required Packages**:
  ```bash
  sudo pacman -S --needed archiso pacman-contrib libisoburn systemd edk2-ovmf qemu-desktop
  ```
  - `archiso`: Provides the `mkarchiso` build engine and default profiles.
  - `pacman-contrib`: Provides `pactree` for recursive dependency tree calculation.
  - `libisoburn`: Provides `xorriso` for ISO image manipulation.
  - `edk2-ovmf` & `qemu-desktop` _(Optional)_: For local UEFI virtual machine testing.

---

## Build Instructions

Execute each stage in sequential numerical order from the repository root.

### Step 1: Workspace Initialization

Initializes a clean working directory at `/iso` and copies project sources:

```bash
chmod +x 1_init 2_pkgs 3_releng 4_build
./1_init
cd /iso
```

### Step 2: Offline Package Assembly

Reads [`etc/skel/packages_collection.x86_64`](etc/skel/packages_collection.x86_64), filters official repository packages against the sync database, computes recursive dependencies using `pactree`, downloads `.pkg.tar.zst` files into `mePkg/`, and generates the repository index:

```bash
./2_pkgs
```

_Generated artifacts:_

- `packages.x86_64`: Sanitized unique package list from the collection manifest.
- `packages_pacman.x86_64`: Filtered list of official repository packages (excluding AUR/foreign packages).
- `deps.txt`: Recursively resolved dependency list.
- `mePkg/`: Directory containing all `.pkg.tar.zst` files and `mePkg.db.tar.gz`.
- `mePkg.tar`: Portability archive of the repository directory.

### Step 3: Archiso Profile Customization

Copies the base `releng` profile and overlays custom configurations:

```bash
./3_releng
```

_Customizations applied:_

- Copies standard `releng` profile into `archlive`.
- Saves `packages.x86_64` and `packages_pacman.x86_64` into `etc/skel/`.
- Overlays custom configuration tree (`etc/*`) into `archlive/airootfs/etc/`.
- Appends live environment packages from [`packages_live.x86_64`](packages_live.x86_64) into `archlive/packages.x86_64`.
- Enforces user authentication by removing tty1 autologin (`getty@tty1.service.d/autologin.conf`).
- Configures UEFI boot entries with `copytoram=no` and expands copy-on-write overlay space (`cow_spacesize=100%`).

### Step 4: ISO Compilation and Repository Injection

Compiles the live squashfs image and injects the offline `mePkg` repository directly into the ISO filesystem structure:

```bash
./4_build
```

Progress is written to `build.log`. Monitor in real time:

```bash
tail -f build.log
```

Upon completion, the final bootable ISO is located at:

```
out/cstm-archlinux-<timestamp>-x86_64-wrepo.iso
```

---

## How-To Operations Guide

### How to Test the ISO in a Virtual Machine (QEMU/KVM)

Before writing the ISO to physical media, verify it in a virtual machine:

```bash
# Locate generated image
ISO_PATH=$(ls out/*-wrepo.iso | head -n 1)

# Create a temporary virtual disk
qemu-img create -f qcow2 test-disk.img 20G

# Launch with UEFI (OVMF) support and KVM acceleration
qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -bios /usr/share/edk2/x64/OVMF.4m.fd \
  -cdrom "$ISO_PATH" \
  -drive file=test-disk.img,format=qcow2,if=virtio \
  -boot d
```

### How to Write the ISO to a USB Drive

#### Method A: Direct Block Write (`dd`)

> [!CAUTION]
> Ensure the target drive (`/dev/sdX`) is correct. Writing to an incorrect block device will result in irreversible data loss.

1. Identify the USB device name:
   ```bash
   lsblk
   ```
2. Unmount any active partitions on the device:
   ```bash
   sudo umount /dev/sdX* 2>/dev/null || true
   ```
3. Write the image:
   ```bash
   ISO_PATH=$(ls out/*-wrepo.iso | head -n 1)
   sudo dd if="$ISO_PATH" of=/dev/sdX bs=4M status=progress oflag=sync
   ```

#### Method B: Ventoy (Recommended for Multiboot)

Copy the generated `*-wrepo.iso` directly into the data partition of a Ventoy-prepared USB drive.

---

### How to Deploy to Target Hardware (Offline Installation)

1. **Boot into the Live System**:
   Select the UEFI boot entry for the customized Arch Linux ISO.
2. **Launch Graphical Environment (Optional)**:
   If a graphical desktop is needed during live diagnostics:
   ```bash
   gui
   ```
3. **Identify the Destination Drive**:
   ```bash
   lsblk
   ```
4. **Execute the Automated Installer**:
   Set the `DRIVE` variable to the base device name (defaults to `sda` if omitted):
   - For SATA / USB drives:
     ```bash
     export DRIVE=sda
     sudo -E bash /etc/skel/install-live.sh
     ```
   - For NVMe drives:
     ```bash
     export DRIVE=nvme0n1
     sudo -E bash /etc/skel/install-live.sh
     ```
5. **Set Passwords and User Credentials**:
   During execution, the installer switches into `arch-chroot` and prompts for:
   - Root user password.
   - Password for the administrative account (`toocels`).
6. **Reboot into Installed System**:
   ```bash
   reboot
   ```

---

### How to Customize Live Environment Packages

To include additional troubleshooting utilities, window managers, or drivers in the live boot environment:

1. Open [packages_live.x86_64](packages_live.x86_64).
2. Append package names (one per line):
   ```text
   htop
   neovim
   wireguard-tools
   ```
3. Re-run `./3_releng` and `./4_build`.

---

### How to Manage Target Packages in packages_collection.x86_64

The target installation package list is maintained in [`etc/skel/packages_collection.x86_64`](etc/skel/packages_collection.x86_64).

- Lines starting with `#` are treated as comments and ignored.
- Inline comments (`# comment`) and empty lines are automatically stripped by `2_pkgs`.
- Official packages are downloaded into the offline `mePkg` repository.
- Foreign/AUR packages (e.g. `yay`, `brave-origin-bin`, `rustdesk-bin`) are preserved in `packages.x86_64` for post-installation setup.

> [!NOTE]
> **Virtual Package Resolution Notes:**
>
> - **Java / JDK**: Packages such as `dbeaver` depend on `java-runtime>=21`, which Pacman resolves by pulling OpenJDK. Commenting out `dbeaver` eliminates Java dependencies from the offline repository.
> - **Vulkan / NVIDIA**: Packages such as `zed` require `vulkan-driver`. If your host system has `nvidia-utils` installed, Pacman may select `nvidia-utils` as the provider for `vulkan-driver`.

---

### How to Customize Default Credentials and Users

User and group configurations for the live environment are stored in `etc/`:

1. Modify `etc/passwd` and `etc/shadow` to update default usernames, shell assignments, or password hashes.
2. Modify [`etc/skel/install-chroot.sh`](etc/skel/install-chroot.sh) to change target install values:
   ```bash
   HOSTNAME="mycustomhost"
   USERNAME="admin"
   ```

---

### How to Perform a Clean Rebuild

To wipe intermediate build artifacts, cached profiles, and partial ISO images:

```bash
# Clean working directories (3_releng removes/recreates archlive itself)
sudo rm -rf /iso/work /iso/out /iso/build.log

# Re-run pipeline from stage 3 (if mePkg is preserved) or stage 1 (for full rebuild)
./3_releng
./4_build
```

---

### How to Troubleshoot Build Issues

| Issue                                             | Cause                                               | Solution                                                                                                                                    |
| :------------------------------------------------ | :-------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------ |
| **Out of disk space**                             | `/iso` or `/tmp` filled during squashfs compression | Ensure `/iso` is on a filesystem with at least 25 GB free space.                                                                            |
| **`pactree: [unresolvable]` errors**              | Package name changed or missing upstream            | Inspect `deps.txt` and verify packages exist in active `pacman` mirrors.                                                                    |
| **`systemd-run: CPUQuota` throttle too high/low** | Host core count constraints                         | Modify the `quota` calculation in [4_build](4_build) (e.g., `quota=200%` for 2 full cores). |
| **Pacman signature failure in `2_pkgs`**          | Outdated host Arch keyring                          | Update keyring prior to build: `sudo pacman -Sy archlinux-keyring`.                                                                         |

---

## Configuration Reference

- [packages_live.x86_64](packages_live.x86_64): Packages installed into the live ISO environment.
- [`etc/skel/packages_collection.x86_64`](etc/skel/packages_collection.x86_64): Declarative manifest of packages bundled for target installation and offline caching.
- [`etc/skel/install-live.sh`](etc/skel/install-live.sh): Automated disk wipe, GPT creation, formatting, and offline pacstrap logic.
- [`etc/skel/install-chroot.sh`](etc/skel/install-chroot.sh): Automated post-installation locale, daemon, user, and boot configuration.

---

## License

This project is licensed under the terms of the **GNU General Public License v3.0** (GPL-3.0-or-later). See the [LICENSE](LICENSE) file for complete terms and conditions.
