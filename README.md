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
  - [Step 1: Offline Package Assembly](#step-1-offline-package-assembly)
  - [Step 2: Archiso Profile Customization](#step-2-archiso-profile-customization)
  - [Step 3: ISO Compilation and Repository Injection](#step-3-iso-compilation-and-repository-injection)
  - [Step 4: Build Artifact Cleanup](#step-4-build-artifact-cleanup)
- [How-To Operations Guide](#how-to-operations-guide)
  - [How to Test the ISO in a Virtual Machine (QEMU/KVM)](#how-to-test-the-iso-in-a-virtual-machine-qemukvm)
  - [How to Write the ISO to a USB Drive](#how-to-write-the-iso-to-a-usb-drive)
  - [How to Deploy to Target Hardware (Offline Installation)](#how-to-deploy-to-target-hardware-offline-installation)
  - [How to Customize Live Environment Packages](#how-to-customize-live-environment-packages)
  - [How to Manage Target Packages in packages_collection.x86_64](#how-to-manage-target-packages-in-packages_collectionx86_64)
  - [How to Customize the Installed Hostname and User](#how-to-customize-the-installed-hostname-and-user)
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
- **Customized Live Environment**: Bundles administrative utilities (GNOME Terminal, Disks, GParted, TestDisk, Nmap, Fastfetch, Timeshift, `sbctl`, and Btrfs/LVM toolchains) into the live boot medium.
- **Resource-Constrained Compilation**: Uses `systemd-run --scope -p CPUQuota` to throttle CPU usage during intensive `mkarchiso` squashfs compression, keeping host systems responsive.
- **Direct ISO Layer Injection**: Leverages `xorriso` to graft the offline package repository directly into the built ISO structure without requiring a full live squashfs rebuild.
- **Automated Target Provisioning**: Ships automated installation scripts ([`install-live.sh`](etc/skel/install-live.sh) and [`install-chroot.sh`](etc/skel/install-chroot.sh)) to automate GPT disk partitioning, filesystem formatting, offline pacstrapping from the local repository, and initial system configuration.
- **Free and Open-Source Software**: Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).

---

## Project Architecture

### Build Pipeline

The build workflow is structured into four sequential, decoupled stages:

```
[1_pkgs]    --> Reads etc/skel/packages_collection.x86_64, resolves deps, builds mePkg.db
    |
[2_releng]  --> Configures archlive profile, overlays custom /etc
    |
[3_build]   --> Compiles live ISO (mkarchiso) & injects offline repository (xorriso)
    |
[4_cleanup] --> Removes intermediate/output artifacts from stages 1-3
```

### Directory Layout

```
.
├── 1_pkgs                         # Stage 1: Offline package resolution and mePkg repository builder
├── 2_releng                       # Stage 2: Archiso profile configuration and overlay staging
├── 3_build                        # Stage 3: ISO compilation and xorriso repository injection
├── 4_cleanup                      # Stage 4: Removes build artifacts from stages 1-3
├── etc/                           # Custom configuration overlays for live and installed systems
│   └── skel/                      # Dropped directly into archlive/airootfs/root/ (see Step 2)
│       ├── .zshrc                 # Shell startup configuration and aliases (e.g. gui launcher)
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

---

## Build Instructions

Execute each stage in sequential numerical order from the repository root.

```bash
chmod +x 1_pkgs 2_releng 3_build 4_cleanup
```

### Step 1: Offline Package Assembly

Reads [`etc/skel/packages_collection.x86_64`](etc/skel/packages_collection.x86_64), filters official repository packages against the sync database, computes recursive dependencies using `pactree`, downloads `.pkg.tar.zst` files into `mePkg/`, and generates the repository index:

```bash
./1_pkgs
```

_Generated artifacts:_

- `packages.x86_64`: Sanitized unique package list from the collection manifest.
- `packages_pacman.x86_64`: Filtered list of official repository packages (excluding AUR/foreign packages).
- `mePkg/`: Directory containing all `.pkg.tar.zst` files and `mePkg.db.tar.gz`.
- `mePkg.tar`: Portability archive of the repository directory.

(`deps.txt` is an intermediate dependency list, deleted by the script itself once `mePkg` is built.)

### Step 2: Archiso Profile Customization

Copies the base `releng` profile and overlays custom configurations:

```bash
./2_releng
```

_Customizations applied:_

- Copies standard `releng` profile into `archlive`.
- Bakes the `ROOT_PASSWORD` variable (default `l`) into `archlive/airootfs/etc/shadow` as root's password. tty1 autologin (`releng` default) bypasses this entirely — it only matters for SSH/`su`/`sudo`.
- Switches live-ISO networking from `releng`'s default `systemd-networkd`/`iwd` stack to `NetworkManager` (enabled via a `multi-user.target.wants` symlink, same mechanism `releng` itself uses), so it's running — and the only thing managing the interface — by boot. `iwd` stays enabled as NetworkManager's wifi backend via a `NetworkManager/conf.d` drop-in, since `wpa_supplicant` isn't in the package list.
- Saves `packages.x86_64` and `packages_pacman.x86_64` into `etc/skel/`.
- Drops `etc/skel/`'s contents (install scripts, manifests, `.zshrc`) directly into `archlive/airootfs/root/` (not `archlive/airootfs/etc/skel/`, which would collide with `grml-zsh-config`'s own `/etc/skel/.zshrc` during pacstrap).
- Appends live environment packages from [`packages_live.x86_64`](packages_live.x86_64) into `archlive/packages.x86_64`.
- Keeps the `releng` default: tty1 autologin as `root` (no password prompt), and `sshd` already enabled with `PermitRootLogin yes` / `PasswordAuthentication yes` via `etc/ssh/sshd_config.d/10-archiso.conf`.
- Configures UEFI boot entries with `copytoram=no` and expands copy-on-write overlay space (`cow_spacesize=50%`).

### Step 3: ISO Compilation and Repository Injection

Compiles the live squashfs image under a CPU-quota-limited `systemd-run` scope (so `mkarchiso` doesn't lock up the host), then injects the offline `mePkg` repository directly into the ISO filesystem structure:

```bash
./3_build
```

The quota ceiling is a plain variable at the top of the script (`CPU_QUOTA_PERCENT_PER_CORE=90`, multiplied by `nproc` to get the final `systemd-run -p CPUQuota=` value). Output is streamed to both the console and `build.log` simultaneously via `tee`.

Upon completion, the final bootable ISO is located at:

```
out/cstm-archlinux-<timestamp>-x86_64-wrepo.iso
```

### Step 4: Build Artifact Cleanup

Removes every intermediate and output file generated by `1_pkgs`, `2_releng`, and `3_build` (`mePkg/`, `archlive/`, `work/`, `out/`, `build.log`, generated package lists), restoring the repo to its pre-build source state:

```bash
./4_cleanup
```

`work/` and `out/` are created by `mkarchiso` running as root (via `sudo systemd-run` in `3_build`), so this step uses `sudo` for those two paths only.

---

## How-To Operations Guide

### How to Deploy to Target Hardware (Offline Installation)

1. **Boot into the Live System**:
   Select the UEFI boot entry for the customized Arch Linux ISO.
2. **Launch Graphical Environment (Optional)**:
   If a graphical desktop is needed during live diagnostics:
   ```bash
   gui
   ```
   Alternatively, drive the install remotely over SSH — both `sshd` and `NetworkManager` are enabled and running by the time the ISO finishes booting, no manual steps needed:
   ```bash
   ssh root@<live-machine-ip>   # password: l
   ```
   `releng`'s `etc/ssh/sshd_config.d/10-archiso.conf` already sets `PermitRootLogin yes` + `PasswordAuthentication yes`, and [`2_releng`](2_releng) bakes a root password (`ROOT_PASSWORD` at the top of the script, default `l`) straight into `archlive/airootfs/etc/shadow` at build time.
   > [!WARNING]
   > `l` is a throwaway test password baked into every ISO this project builds. Change `ROOT_PASSWORD` in [`2_releng`](2_releng) before building anything that will touch a network you don't fully trust.
3. **Identify the Destination Drive**:
   ```bash
   lsblk
   ```
4. **Execute the Automated Installer**:
   Set the `DRIVE` variable to the base device name (defaults to `sda` if omitted):
   `install-live.sh` is dropped into `/root` (root's live-session home), so it's already on hand after autologin:
   - For SATA / USB drives:
     ```bash
     export DRIVE=sda
     bash ~/install-live.sh
     ```
   - For NVMe drives:
     ```bash
     export DRIVE=nvme0n1
     bash ~/install-live.sh
     ```
5. **Set Account Passwords**:
   During execution, the installer switches into `arch-chroot`, prompts for the root password, then creates the admin user (`USERNAME` in [`install-chroot.sh`](etc/skel/install-chroot.sh), default `toocels`) and prompts for its password too.
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
3. Re-run `./2_releng` and `./3_build`.

---

### How to Manage Target Packages in packages_collection.x86_64

The target installation package list is maintained in [`etc/skel/packages_collection.x86_64`](etc/skel/packages_collection.x86_64).

- Lines starting with `#` are treated as comments and ignored.
- Inline comments (`# comment`) and empty lines are automatically stripped by `1_pkgs`.
- Official packages are downloaded into the offline `mePkg` repository.
- Foreign/AUR packages (e.g. `yay`, `brave-origin-bin`, `rustdesk-bin`) are preserved in `packages.x86_64` for post-installation setup.

> [!NOTE]
> **Virtual Package Resolution Notes:**
>
> - **Java / JDK**: Packages such as `dbeaver` depend on `java-runtime>=21`, which Pacman resolves by pulling OpenJDK. Commenting out `dbeaver` eliminates Java dependencies from the offline repository.
> - **Vulkan / NVIDIA**: Packages such as `zed` require `vulkan-driver`. If your host system has `nvidia-utils` installed, Pacman may select `nvidia-utils` as the provider for `vulkan-driver`.

---

### How to Customize the Installed Hostname and User

The live ISO itself uses only the `root` account — no separate user is
created there, and no `etc/passwd`/`etc/group` overlay is shipped. tty1
autologin stays passwordless (the stock `releng` default), but root does get
a baked-in password for SSH — see `ROOT_PASSWORD` in [`2_releng`](2_releng).

The **installed** system is different: [`install-chroot.sh`](etc/skel/install-chroot.sh)
sets a root password, then creates an admin user (added to `wheel` and, if
present, `docker`) and sets its password too. Both the hostname and the
username are plain variables at the top of the script:

```bash
HOSTNAME="mycustomhost"
USERNAME="myuser"
```

---

### How to Perform a Clean Rebuild

Use [`4_cleanup`](4_cleanup) to wipe intermediate build artifacts, cached profiles, and partial ISO images, then re-run whichever stages you need:

```bash
./4_cleanup

# Re-run from stage 2 (if mePkg is preserved) or stage 1 (for a full rebuild)
./2_releng
./3_build
```

---

### How to Troubleshoot Build Issues

| Issue                                                            | Cause                                                                                                                                                          | Solution                                                                                                                                                                                                                                                                  |
| :--------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Out of disk space**                                            | Repo working directory or `/tmp` filled during squashfs compression                                                                                            | Ensure the repo clone is on a filesystem with at least 25 GB free space.                                                                                                                                                                                                  |
| **`pactree: [unresolvable]` errors**                             | Package name changed or missing upstream                                                                                                                       | `deps.txt` is deleted at the end of a successful `1_pkgs` run (and again, just in case, by `4_cleanup`) — comment out its final `rm -f deps.txt` line temporarily to inspect it, or check against active `pacman` mirrors directly.                                       |
| **`systemd-run: CPUQuota` throttle too high/low**                | Host core count constraints                                                                                                                                    | Adjust `CPU_QUOTA_PERCENT_PER_CORE` at the top of [3_build](3_build) (e.g., `100` to allow a full core per CPU).                                                                                                                                                          |
| **Pacman signature failure in `1_pkgs`**                         | Outdated host Arch keyring                                                                                                                                     | Update keyring prior to build: `sudo pacman -Sy archlinux-keyring`.                                                                                                                                                                                                       |
| **`install-live.sh` fdisk fails with `Device or resource busy`** | Something (commonly `udisks2` auto-probing, or a leftover mount/swap from a prior attempt) briefly held the disk while the kernel reloaded the partition table | The script already retries via `partprobe`/`udevadm settle` after a single merged `fdisk` session. If it still fails, `swapoff`/`umount` anything referencing the target drive first, or just re-run the script — the partition table itself was already written to disk. |

---

## Configuration Reference

- [packages_live.x86_64](packages_live.x86_64): Packages installed into the live ISO environment.
- [`etc/skel/packages_collection.x86_64`](etc/skel/packages_collection.x86_64): Declarative manifest of packages bundled for target installation and offline caching.
- [`etc/skel/install-live.sh`](etc/skel/install-live.sh): Automated disk wipe, GPT creation, formatting, and offline pacstrap logic.
- [`etc/skel/install-chroot.sh`](etc/skel/install-chroot.sh): Automated post-installation locale, daemon, user, and boot configuration.

---

## License

This project is licensed under the terms of the **GNU General Public License v3.0** (GPL-3.0-or-later). See the [LICENSE](LICENSE) file for complete terms and conditions.
