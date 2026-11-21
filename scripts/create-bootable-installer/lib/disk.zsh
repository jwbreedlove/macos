# External disk discovery, selection, and safety confirmations

typeset -g MCI_DISK_ID=""
typeset -g MCI_DISK_SIZE=""
typeset -g MCI_DISK_NAME=""
typeset -g MCI_VOLUME_NAME="Install macOS"
typeset -ga MCI_EXTERNAL_DISKS=()

# Populate MCI_EXTERNAL_DISKS with diskN identifiers (external physical only).
mci::disk::list_external_ids() {
  MCI_EXTERNAL_DISKS=()
  local line id
  local -a match mbegin mend
  # Prefer diskutil's external physical filter; fall back to parsing list.
  local out
  out="$(diskutil list external physical 2>/dev/null)" || out="$(diskutil list external 2>/dev/null)" || out=""

  if [[ -z $out ]]; then
    return 0
  fi

  while IFS= read -r line; do
    if [[ $line =~ ^/dev/(disk[0-9]+)([[:space:]]|$) ]]; then
      id="${match[1]}"
      MCI_EXTERNAL_DISKS+=("$id")
    elif [[ $line =~ identifier:[[:space:]]+(disk[0-9]+) ]]; then
      MCI_EXTERNAL_DISKS+=("${match[1]}")
    fi
  done <<< "$out"

  # Deduplicate while preserving order
  local -a uniq=()
  local d
  for d in "${MCI_EXTERNAL_DISKS[@]}"; do
    if (( ! ${uniq[(Ie)$d]} )); then
      uniq+=("$d")
    fi
  done
  MCI_EXTERNAL_DISKS=("${uniq[@]}")
}

mci::disk::info_line() {
  local id="$1"
  local info size name conn
  info="$(diskutil info "$id" 2>/dev/null)" || {
    print -r -- "$id  (unavailable)"
    return 1
  }
  size="$(print -r -- "$info" | awk -F: '/Disk Size/ {gsub(/^ +| +$/,"",$2); print $2; exit}')"
  name="$(print -r -- "$info" | awk -F: '/Media Name|Volume Name/ {gsub(/^ +| +$/,"",$2); print $2; exit}')"
  conn="$(print -r -- "$info" | awk -F: '/Protocol|Device Location/ {gsub(/^ +| +$/,"",$2); print $2; exit}')"
  print -r -- "$id  size=${size:-?}  name=${name:-?}  conn=${conn:-?}"
}

mci::disk::is_internal() {
  local id="$1"
  local info loc internal
  info="$(diskutil info "$id" 2>/dev/null)" || return 0
  loc="$(print -r -- "$info" | awk -F: '/Device Location/ {gsub(/^ +| +$/,"",$2); print tolower($2); exit}')"
  internal="$(print -r -- "$info" | awk -F: '/Internal/ {gsub(/^ +| +$/,"",$2); print tolower($2); exit}')"
  [[ $loc == internal || $internal == yes ]]
}

mci::disk::is_external() {
  local id="$1"
  ! mci::disk::is_internal "$id"
}

mci::disk::has_volumes_or_data() {
  local id="$1"
  local list
  list="$(diskutil list "$id" 2>/dev/null)" || return 1
  # Any partition scheme content beyond a blank/empty disk counts as non-empty.
  # diskutil shows " #: TYPE NAME SIZE IDENTIFIER" rows for partitions.
  print -r -- "$list" | grep -Eq 'disk[0-9]+s[0-9]+'
}

mci::disk::print_external() {
  mci::disk::list_external_ids
  if (( ${#MCI_EXTERNAL_DISKS[@]} == 0 )); then
    print -r -- "No external physical disks found."
    return 0
  fi
  local d
  print -r -- "External disks:"
  for d in "${MCI_EXTERNAL_DISKS[@]}"; do
    print -r -- "  $(mci::disk::info_line "$d")"
  done
}

mci::disk::require_external_present() {
  mci::disk::list_external_ids
  if (( ${#MCI_EXTERNAL_DISKS[@]} == 0 )); then
    mci::log::die "$MCI_E_DISK" "No external disk attached. Plug in a USB/Thunderbolt drive (≥16 GB, 32 GB+ preferred) and retry."
  fi
}

mci::disk::select() {
  local pref="${1:-}"
  local choice=""
  local -a match mbegin mend

  mci::disk::require_external_present

  if [[ -n $pref ]]; then
    pref="${pref#/dev/}"
    if [[ ! $pref =~ ^disk[0-9]+$ ]]; then
      mci::log::die "$MCI_E_USAGE" "Invalid --disk value '$pref' (expected diskN, e.g. disk4)."
    fi
    if mci::disk::is_internal "$pref"; then
      mci::log::die "$MCI_E_DISK" "Refusing internal disk: $pref. Only external disks are allowed."
    fi
    if (( ! ${MCI_EXTERNAL_DISKS[(Ie)$pref]} )); then
      mci::log::die "$MCI_E_DISK" "Disk $pref is not in the external disk list."
    fi
    choice="$pref"
    mci::log::info "Pre-selected disk: $(mci::disk::info_line "$choice")"
  else
    mci::disk::print_external
    print -r -- ""
    print -n -- "Select external disk identifier (e.g. disk4): "
    read -r choice
    choice="${choice##[[:space:]]#}"
    choice="${choice%%[[:space:]]#}"
    choice="${choice#/dev/}"
    if [[ -z $choice ]]; then
      mci::log::die "$MCI_E_ABORT" "No disk selected; aborting."
    fi
    if [[ ! $choice =~ ^disk[0-9]+$ ]]; then
      mci::log::die "$MCI_E_USAGE" "Invalid disk identifier '$choice' (expected diskN)."
    fi
    if mci::disk::is_internal "$choice"; then
      mci::log::die "$MCI_E_DISK" "Refusing internal disk: $choice."
    fi
    if (( ! ${MCI_EXTERNAL_DISKS[(Ie)$choice]} )); then
      mci::log::die "$MCI_E_DISK" "Disk $choice is not in the external disk list."
    fi
  fi

  MCI_DISK_ID="$choice"
  MCI_DISK_SIZE="$(diskutil info "$choice" 2>/dev/null | awk -F: '/Disk Size/ {gsub(/^ +| +$/,"",$2); print $2; exit}')"
  MCI_DISK_NAME="$(diskutil info "$choice" 2>/dev/null | awk -F: '/Media Name/ {gsub(/^ +| +$/,"",$2); print $2; exit}')"
}

# Confirm non-empty + require typing the disk id. No --yes escape hatch.
mci::disk::confirm_wipe() {
  local id="$MCI_DISK_ID"
  local reply

  [[ -n $id ]] || mci::log::die "$MCI_E_DISK" "No disk selected."

  mci::log::warn "About to ERASE entire external disk: /dev/$id"
  mci::log::warn "This destroys ALL volumes and data on that disk."
  mci::log::warn "This tool never erases the Mac internal system disk, and never runs the installer onto it."

  if mci::disk::has_volumes_or_data "$id"; then
    mci::log::warn "Disk $id appears NON-EMPTY (has partitions/volumes)."
    print -n -- "Type YES to confirm you intend to wipe this non-empty disk: "
    read -r reply
    if [[ $reply != YES ]]; then
      mci::log::die "$MCI_E_ABORT" "Confirmation not YES; aborting (disk untouched)."
    fi
  else
    mci::log::info "Disk $id appears empty (no partition slices detected)."
  fi

  print -n -- "Type the disk identifier exactly ($id) to proceed with erase: "
  read -r reply
  reply="${reply##[[:space:]]#}"
  reply="${reply%%[[:space:]]#}"
  reply="${reply#/dev/}"
  if [[ $reply != "$id" ]]; then
    mci::log::die "$MCI_E_ABORT" "Typed identifier '$reply' does not match $id; aborting (disk untouched)."
  fi

  mci::log::info "Wipe confirmation accepted for $id."
}
