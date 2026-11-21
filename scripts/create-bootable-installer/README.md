# create-bootable-installer

Apple Silicon–only zsh tool that downloads the **latest** full macOS installer with Apple’s `softwareupdate` and writes a **bootable install USB** (or other external disk) with `createinstallmedia`.

It does **not** erase your Mac’s internal disk and does **not** run the installer for you. You boot the USB yourself when you are ready for a clean install. Intel/x86_64 Macs are not supported.

## Requirements

| Need | Detail |
| --- | --- |
| Host | macOS on **Apple Silicon** (arm64) only — Intel/x86_64 refused |
| Tools | Built-in only: `softwareupdate`, `diskutil`, `createinstallmedia` |
| Privileges | Admin/`sudo` only at erase/write time |
| Space | Room for the full installer (~12–15+ GB) plus target ≥ ~16 GB (32 GB+ USB preferred) |
| Network | Reachability to Apple software update / CDN |

No Mist, App Store downloads, or reuse of an existing Installer.app — catalog + fetch only.

## Install / run

Preferred (no clone) — see the [root Install section](../../README.md#install):

```zsh
curl -fsSL https://raw.githubusercontent.com/jwbreedlove/macos/main/install | zsh
create-bootable-installer --help
```

From a clone:

```zsh
git clone https://github.com/jwbreedlove/macos.git
cd macos
./scripts/create-bootable-installer/bin/create-bootable-installer --help
```

## Usage

```text
create-bootable-installer [--dry-run]
  [--disk diskN] [--volume-name <name>]
  [--list-installers] [--list-disks]
```

| Flag | Behavior |
| --- | --- |
| `--dry-run` | Resolve latest installer + proposed disk actions; **no** download, erase, or write |
| `--list-installers` | Print Apple full-installer catalog and the selected latest entry |
| `--list-disks` | List external physical disks |
| `--disk diskN` | Pre-select an external disk (confirmations still required) |
| `--volume-name NAME` | Name used with `diskutil eraseDisk` (default: `Install macOS`) |

### Typical flow

```zsh
TOOL=./scripts/create-bootable-installer/bin/create-bootable-installer

# Inspect
$TOOL --list-installers
$TOOL --list-disks
$TOOL --dry-run

# Create bootable media (interactive disk pick + typed confirmations)
$TOOL
```

## Safety warnings

- **External disks only.** Internal / boot disks are refused.
- **Wiping is destructive.** Everything on the selected external disk is erased.
- If the disk is **not empty**, you must type `YES`, then type the disk id (e.g. `disk4`) exactly.
- There is **no** `--yes` or skip-confirm flag.
- This tool **never** automates installing onto, or wiping, the Mac internal system disk.
- Use only for personal / authorized machines. Do not redistribute the downloaded installer.

## How to boot the USB (manual, Apple Silicon)

After the script finishes, shut down the Apple Silicon Mac you want to clean-install, then:

1. Connect the USB install drive.
2. Press and hold the power button until startup options appear.
3. Choose the external **Install macOS …** volume → Continue.
4. In macOS Recovery / Installer, use Disk Utility if you need to erase the *internal* Macintosh HD, then run Install macOS.

The script stops after media creation. Erasing the internal disk and running the installer are deliberate manual steps.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | Aborted / general failure |
| 2 | Usage error |
| 3 | Not macOS / not Apple Silicon / missing host tools |
| 4 | Catalog or download failure |
| 5 | Disk selection / safety failure |
| 6 | Erase or `createinstallmedia` failure |

## Layout

```text
scripts/create-bootable-installer/
  bin/create-bootable-installer
  lib/host.zsh
  lib/download.zsh
  lib/disk.zsh
  lib/media.zsh
  lib/log.zsh
  README.md
```

## Limitations

- “Latest” means whatever Apple’s catalog shows **on that Mac**. Older hosts may not see the newest installer; the script fails clearly — no fallbacks.
- Linux CI can lint syntax only; real download and media creation require Apple Silicon macOS + external storage.
- Manual USB boot / clean-install testing is a separate step from using this script.
