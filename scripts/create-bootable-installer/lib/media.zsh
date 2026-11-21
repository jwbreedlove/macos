# Erase external disk and run createinstallmedia

mci::media::erase_disk() {
  local id="$MCI_DISK_ID"
  local name="${MCI_VOLUME_NAME:-Install macOS}"

  [[ -n $id ]] || mci::log::die "$MCI_E_DISK" "No disk selected for erase."

  mci::log::info "Unmounting disk $id..."
  diskutil unmountDisk force "$id" >/dev/null 2>&1 || true

  mci::log::info "Erasing $id as JHFS+ GPT named '$name'..."
  if ! diskutil eraseDisk JHFS+ "$name" GPT "$id"; then
    mci::log::die "$MCI_E_MEDIA" "diskutil eraseDisk failed for $id."
  fi
}

mci::media::create() {
  local app="$MCI_INSTALLER_APP"
  local name="${MCI_VOLUME_NAME:-Install macOS}"
  local vol="/Volumes/$name"
  local cim

  [[ -n $app && -d $app ]] || mci::log::die "$MCI_E_DOWNLOAD" "Installer app missing: ${app:-unset}"
  cim="$app/Contents/Resources/createinstallmedia"
  [[ -x $cim ]] || mci::log::die "$MCI_E_DOWNLOAD" "createinstallmedia not executable: $cim"

  if [[ ! -d $vol ]]; then
    mci::log::die "$MCI_E_MEDIA" "Expected volume not mounted at $vol after erase."
  fi

  mci::log::info "Running createinstallmedia on $vol (sudo required)..."
  mci::log::info "This can take a while; do not unplug the drive."

  if ! sudo "$cim" --volume "$vol" --nointeraction; then
    mci::log::die "$MCI_E_MEDIA" "createinstallmedia failed."
  fi
}

mci::media::verify() {
  local name="${MCI_VOLUME_NAME:-Install macOS}"
  # createinstallmedia often renames the volume to match the installer.
  local -a candidates=()
  local vol

  candidates=("/Volumes/$name")
  if [[ -n $MCI_INSTALLER_TITLE ]]; then
    candidates+=("/Volumes/Install $MCI_INSTALLER_TITLE")
  fi
  # Any Install macOS * volume
  candidates+=(/Volumes/Install\ macOS\ *(N))

  for vol in "${candidates[@]}"; do
    if [[ -d $vol ]]; then
      mci::log::info "Install volume present: $vol"
      mci::log::info "Media creation succeeded for ${MCI_INSTALLER_TITLE:-macOS} ${MCI_INSTALLER_VERSION:-?} (build ${MCI_INSTALLER_BUILD:-?})."
      mci::log::info "Next: boot from this USB on a Mac (see README). This tool does NOT install onto the internal disk."
      return 0
    fi
  done

  mci::log::die "$MCI_E_MEDIA" "Could not find Install volume under /Volumes after createinstallmedia."
}

mci::media::dry_run_summary() {
  print -r -- ""
  print -r -- "=== dry-run summary (no download / erase / write) ==="
  print -r -- "Installer: ${MCI_INSTALLER_TITLE:-?} ${MCI_INSTALLER_VERSION:-?} build ${MCI_INSTALLER_BUILD:-?}"
  print -r -- "App path:  ${MCI_INSTALLER_APP:-?}"
  print -r -- "Disk:      ${MCI_DISK_ID:-?} (${MCI_DISK_NAME:-?}, ${MCI_DISK_SIZE:-?})"
  print -r -- "Erase:     diskutil eraseDisk JHFS+ '${MCI_VOLUME_NAME}' GPT ${MCI_DISK_ID:-?}"
  print -r -- "Write:     sudo \"\${app}/Contents/Resources/createinstallmedia\" --volume \"/Volumes/${MCI_VOLUME_NAME}\" --nointeraction"
  print -r -- "===================================================="
}
