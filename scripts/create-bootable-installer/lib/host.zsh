# Host / environment checks

# Exit codes (shared)
typeset -g MCI_E_OK=0
typeset -g MCI_E_ABORT=1
typeset -g MCI_E_USAGE=2
typeset -g MCI_E_HOST=3
typeset -g MCI_E_DOWNLOAD=4
typeset -g MCI_E_DISK=5
typeset -g MCI_E_MEDIA=6

mci::host::is_macos() {
  [[ $(uname -s) == Darwin ]]
}

mci::host::arch() {
  uname -m
}

mci::host::is_apple_silicon() {
  [[ $(mci::host::arch) == arm64 ]]
}

mci::host::require_macos() {
  if ! mci::host::is_macos; then
    mci::log::die "$MCI_E_HOST" \
      "This tool runs only on macOS (needs softwareupdate, diskutil, createinstallmedia)."
  fi
}

# Apple Silicon (arm64) only — refuse Intel/x86_64 hosts.
mci::host::require_apple_silicon() {
  local arch
  arch="$(mci::host::arch)"
  if [[ $arch != arm64 ]]; then
    mci::log::die "$MCI_E_HOST" \
      "Apple Silicon (arm64) only. This host is '$arch' (Intel/x86_64 is not supported)."
  fi
}

mci::host::check_tools() {
  local missing=()
  local cmd
  for cmd in softwareupdate diskutil; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if (( ${#missing[@]} )); then
    mci::log::die "$MCI_E_HOST" "Missing required tools: ${missing[*]}"
  fi
}

mci::host::summary() {
  mci::log::info "Host: $(sw_vers -productName 2>/dev/null || print macOS) $(sw_vers -productVersion 2>/dev/null || print '?') (Apple Silicon, $(mci::host::arch))"
}
