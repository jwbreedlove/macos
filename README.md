# macos

Apple Silicon–oriented scripts for macOS. Each tool lives under `scripts/<tool>/` with its own entrypoint and README.

## Install

No git clone required. On an Apple Silicon Mac:

```zsh
curl -fsSL https://raw.githubusercontent.com/jwbreedlove/macos/main/install | zsh
```

That installs tools under `~/.local/share/macos/<tool>/` and puts symlinks in `~/.local/bin`. If that bin dir is not on your `PATH`, the installer prints a one-line `~/.zshrc` hint.

Until the install script is on `main`, use this branch (or wait for the PR to merge):

```zsh
curl -fsSL https://raw.githubusercontent.com/jwbreedlove/macos/cursor/add-create-bootable-installer-2a4e/install \
  | MACOS_REF=cursor/add-create-bootable-installer-2a4e zsh
```

Useful variants:

```zsh
# List tools
curl -fsSL https://raw.githubusercontent.com/jwbreedlove/macos/main/install | zsh -s -- --list

# Install one tool
curl -fsSL https://raw.githubusercontent.com/jwbreedlove/macos/main/install \
  | zsh -s -- create-bootable-installer

# Custom prefix / bin dir
curl -fsSL https://raw.githubusercontent.com/jwbreedlove/macos/main/install \
  | zsh -s -- --prefix ~/Library/Application\ Support/macos --bin-dir ~/bin

# Uninstall
curl -fsSL https://raw.githubusercontent.com/jwbreedlove/macos/main/install \
  | zsh -s -- --uninstall create-bootable-installer
```

After install, run:

```zsh
create-bootable-installer --help
create-bootable-installer --list-disks
create-bootable-installer --dry-run
```

## Tools

| Tool | Description |
| --- | --- |
| [create-bootable-installer](scripts/create-bootable-installer/README.md) | Download the latest full macOS installer (`softwareupdate`) and write a bootable external install volume (`createinstallmedia`) |

## Quick start (from a clone)

```zsh
git clone https://github.com/jwbreedlove/macos.git
cd macos
./scripts/create-bootable-installer/bin/create-bootable-installer --help
```

Or run the local installer against a checked-out tree’s published ref:

```zsh
./install --list
./install create-bootable-installer
```

## Notes

- **Apple Silicon (arm64) only** — Intel/x86_64 hosts are refused by tools that enforce arch checks.
- Linux CI lints shell syntax only; real macOS download/media work is manual.
- Adding a tool: create `scripts/<tool-name>/` with `bin/<tool-name>`, optional `lib/`, and a README; add the name to `MI_KNOWN_TOOLS` in `install`; extend `.github/workflows/lint.yml` if needed.
