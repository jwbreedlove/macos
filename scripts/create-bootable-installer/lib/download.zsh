# Latest full installer via Apple softwareupdate only

typeset -g MCI_INSTALLER_TITLE=""
typeset -g MCI_INSTALLER_VERSION=""
typeset -g MCI_INSTALLER_BUILD=""
typeset -g MCI_INSTALLER_SIZE=""
typeset -g MCI_INSTALLER_APP=""

# Parse one catalog line into globals (best-effort).
# Example:
# * Title: macOS Sequoia, Version: 15.1, Size: 15000000KiB, Build: 24B83, Deferred: NO
mci::download::parse_line() {
  local line="$1"
  local title="" version="" size="" build=""

  [[ $line == *Title:* ]] || return 1

  title="${line##*Title: }"
  title="${title%%, Version:*}"
  title="${title##[[:space:]]#}"
  title="${title%%[[:space:]]#}"

  version="${line##*Version: }"
  version="${version%%,*}"
  version="${version##[[:space:]]#}"
  version="${version%%[[:space:]]#}"

  size="${line##*Size: }"
  size="${size%%,*}"
  size="${size##[[:space:]]#}"
  size="${size%%[[:space:]]#}"

  build="${line##*Build: }"
  build="${build%%,*}"
  build="${build##[[:space:]]#}"
  build="${build%%[[:space:]]#}"

  [[ -n $title && -n $version ]] || return 1

  MCI_INSTALLER_TITLE="$title"
  MCI_INSTALLER_VERSION="$version"
  MCI_INSTALLER_BUILD="$build"
  MCI_INSTALLER_SIZE="$size"
  return 0
}

# Compare dotted versions: returns 0 if $1 > $2, 1 otherwise.
mci::download::version_gt() {
  local a="$1" b="$2"
  local -a aa ba
  local -a match mbegin mend
  local i n av bv

  aa=(${(s:.:)a})
  ba=(${(s:.:)b})
  n=$(( ${#aa} > ${#ba} ? ${#aa} : ${#ba} ))
  for (( i = 1; i <= n; i++ )); do
    av=${aa[i]:-0}
    bv=${ba[i]:-0}
    [[ $av =~ ^[0-9]+$ ]] || av=0
    [[ $bv =~ ^[0-9]+$ ]] || bv=0
    if (( av > bv )); then
      return 0
    elif (( av < bv )); then
      return 1
    fi
  done
  return 1
}

mci::download::list_catalog() {
  softwareupdate --list-full-installers 2>&1
}

# Fill MCI_INSTALLER_* with the highest Version in the catalog.
mci::download::resolve_latest() {
  local out line
  local best_title="" best_version="" best_build="" best_size=""
  local cur_title cur_version cur_build cur_size

  out="$(mci::download::list_catalog)" || {
    mci::log::die "$MCI_E_DOWNLOAD" "softwareupdate --list-full-installers failed."
  }

  while IFS= read -r line; do
    if mci::download::parse_line "$line"; then
      cur_title="$MCI_INSTALLER_TITLE"
      cur_version="$MCI_INSTALLER_VERSION"
      cur_build="$MCI_INSTALLER_BUILD"
      cur_size="$MCI_INSTALLER_SIZE"
      if [[ -z $best_version ]] || mci::download::version_gt "$cur_version" "$best_version"; then
        best_title="$cur_title"
        best_version="$cur_version"
        best_build="$cur_build"
        best_size="$cur_size"
      fi
    fi
  done <<< "$out"

  if [[ -z $best_version ]]; then
    mci::log::error "No full installers found in the Apple catalog on this Mac."
    mci::log::error "Older hosts may not see the newest installer. No alternate download paths."
    print -r -- "$out" >&2
    mci::log::die "$MCI_E_DOWNLOAD" "Empty or unparseable installer catalog."
  fi

  MCI_INSTALLER_TITLE="$best_title"
  MCI_INSTALLER_VERSION="$best_version"
  MCI_INSTALLER_BUILD="$best_build"
  MCI_INSTALLER_SIZE="$best_size"
  MCI_INSTALLER_APP="/Applications/Install ${best_title}.app"

  mci::log::info "Latest catalog entry: $MCI_INSTALLER_TITLE $MCI_INSTALLER_VERSION (build ${MCI_INSTALLER_BUILD:-?}, size ${MCI_INSTALLER_SIZE:-?})"
  mci::log::info "Expected app path: $MCI_INSTALLER_APP"
}

mci::download::print_catalog() {
  local out
  out="$(mci::download::list_catalog)" || {
    mci::log::die "$MCI_E_DOWNLOAD" "softwareupdate --list-full-installers failed."
  }
  print -r -- "$out"
  mci::download::resolve_latest
  print -r -- ""
  print -r -- "Selected (latest): $MCI_INSTALLER_TITLE $MCI_INSTALLER_VERSION build ${MCI_INSTALLER_BUILD:-?}"
}

mci::download::fetch() {
  mci::download::resolve_latest

  mci::log::info "Fetching full installer via softwareupdate (this can take a long time)..."
  # Prefer version-qualified fetch so we get the resolved latest entry.
  if ! softwareupdate --fetch-full-installer --full-installer-version "$MCI_INSTALLER_VERSION"; then
    mci::log::warn "Version-qualified fetch failed; retrying without version flag..."
    if ! softwareupdate --fetch-full-installer; then
      mci::log::die "$MCI_E_DOWNLOAD" "softwareupdate --fetch-full-installer failed."
    fi
  fi

  mci::download::validate
}

mci::download::validate() {
  local app="$MCI_INSTALLER_APP"
  local cim

  if [[ -z $app ]]; then
    mci::download::resolve_latest
    app="$MCI_INSTALLER_APP"
  fi

  if [[ ! -d $app ]]; then
    mci::log::die "$MCI_E_DOWNLOAD" \
      "Installer app not found at: $app (no alternate download paths; re-run fetch or check catalog title)."
  fi

  cim="$app/Contents/Resources/createinstallmedia"
  if [[ ! -x $cim ]]; then
    mci::log::die "$MCI_E_DOWNLOAD" "createinstallmedia missing or not executable: $cim"
  fi

  local plist="$app/Contents/Info.plist"
  if [[ -f $plist ]] && command -v defaults >/dev/null 2>&1; then
    local shortver bundlever
    shortver="$(defaults read "$plist" CFBundleShortVersionString 2>/dev/null || true)"
    bundlever="$(defaults read "$plist" CFBundleVersion 2>/dev/null || true)"
    mci::log::info "Validated installer: $app (CFBundleShortVersionString=${shortver:-?}, CFBundleVersion=${bundlever:-?})"
  else
    mci::log::info "Validated installer: $app (createinstallmedia present)"
  fi
}
