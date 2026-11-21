# macos

Apple Silicon–oriented scripts for macOS. Each tool lives under `scripts/<tool>/` with its own entrypoint and README.

## Tools

| Tool | Description |
| --- | --- |
| [create-bootable-installer](scripts/create-bootable-installer/README.md) | Download the latest full macOS installer (`softwareupdate`) and write a bootable external install volume (`createinstallmedia`) |

## Quick start

```zsh
git clone https://github.com/jwbreedlove/macos.git
cd macos
./scripts/create-bootable-installer/bin/create-bootable-installer --help
```

## Notes

- **Apple Silicon (arm64) only** — Intel/x86_64 hosts are refused by tools that enforce arch checks.
- Linux CI lints shell syntax only; real macOS download/media work is manual.
- Adding a tool: create `scripts/<tool-name>/` with `bin/<tool-name>`, optional `lib/`, and a README; extend `.github/workflows/lint.yml` if needed.
