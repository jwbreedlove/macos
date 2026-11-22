# Logging helpers for create-bootable-installer

typeset -g MCI_LOG_TS=1

mci::log::ts() {
  if (( MCI_LOG_TS )); then
    date '+%Y-%m-%d %H:%M:%S'
  fi
}

mci::log::info() {
  local ts
  ts="$(mci::log::ts)"
  if [[ -n $ts ]]; then
    print -r -- "[$ts] INFO  $*"
  else
    print -r -- "INFO  $*"
  fi
}

mci::log::warn() {
  local ts
  ts="$(mci::log::ts)"
  if [[ -n $ts ]]; then
    print -r -- "[$ts] WARN  $*" >&2
  else
    print -r -- "WARN  $*" >&2
  fi
}

mci::log::error() {
  local ts
  ts="$(mci::log::ts)"
  if [[ -n $ts ]]; then
    print -r -- "[$ts] ERROR $*" >&2
  else
    print -r -- "ERROR $*" >&2
  fi
}

mci::log::die() {
  local code="${1:-1}"
  shift
  mci::log::error "$@"
  exit "$code"
}

# Prompt "$1 [y/N]: "; return 0 only for y/Y. Empty Enter and anything else = no.
mci::log::confirm_yn() {
  local prompt="$1"
  local reply
  print -n -- "$prompt [y/N]: "
  read -r reply
  reply="${reply##[[:space:]]#}"
  reply="${reply%%[[:space:]]#}"
  [[ $reply == y || $reply == Y ]]
}
