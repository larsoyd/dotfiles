#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
DEFAULT_BACKUP_ROOT="$REPO_ROOT/backups"
DEFAULT_CONFIG_HOME="${XDG_CONFIG_HOME:-"$HOME/.config"}"

DRY_RUN=false
FORCE=false
SKIP_PACKAGES=false
VERBOSE=false
ASSUME_YES=false
PRINT_PLAN=false
BACKUP_ROOT="$DEFAULT_BACKUP_ROOT"
BACKUP_TIMESTAMP=""

REQUIRED_BINS=(
  hyprland uwsm kitty nautilus fuzzel nm-applet waybar mako app2unit wlogout
  nm-connection-editor
)

INSTALL_PLAN=()

usage() {
  cat <<'USAGE'
Usage: ./setup.sh [options]

Options:
  --dry-run           Print the plan without copying files
  --force             Overwrite existing files without creating backups
  --skip-packages     Skip dependency verification entirely
  --backup-dir DIR    Store backups under DIR (default: ./backups)
  --verbose           Increase log verbosity
  --yes, -y           Assume "yes" for interactive prompts
  --print-plan        Output the resolved install plan and exit
  --help              Show this help text
USAGE
}

log() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*"
}

info() { log INFO "$*"; }
warn() { log WARN "$*" >&2; }
error() { log ERROR "$*" >&2; }

prompt_yes_no() {
  local prompt_text="$1"
  local default_choice="${2:-n}"
  local answer
  if $ASSUME_YES; then
    return 0
  fi
  while true; do
    read -r -p "$prompt_text [y/N]: " answer || return 1
    answer=${answer:-$default_choice}
    case "$answer" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

build_install_plan() {
  local config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}"
  INSTALL_PLAN=("file|$REPO_ROOT/.zprofile|$HOME/.zprofile")

  local config_dir="$REPO_ROOT/.config"
  if [[ -d "$config_dir" ]]; then
    local entry name entry_kind
    local shopt_nullglob_state shopt_dotglob_state
    shopt_nullglob_state=$(shopt -p nullglob)
    shopt_dotglob_state=$(shopt -p dotglob)
    shopt -s nullglob dotglob
    for entry in "$config_dir"/*; do
      [[ -e "$entry" ]] || continue
      name="${entry##*/}"
      if [[ -d "$entry" ]]; then
        entry_kind="dir"
      else
        entry_kind="file"
      fi
      INSTALL_PLAN+=("$entry_kind|$entry|$config_home/$name")
    done
    eval "$shopt_nullglob_state"
    eval "$shopt_dotglob_state"
  fi
}

print_install_plan() {
  build_install_plan
  for entry in "${INSTALL_PLAN[@]}"; do
    IFS='|' read -r kind src dest <<<"$entry"
    printf '%s: %s -> %s\n' "$kind" "$src" "$dest"
  done
}

assert_dir_permissions() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    error "Directory not found: $dir"
    return 1
  fi
  if [[ ! -r "$dir" || ! -w "$dir" ]]; then
    error "Directory lacks required permissions (read/write): $dir"
    return 1
  fi
  local perms
  perms=$(stat -c '%A' "$dir")
  local owner_read=${perms:1:1}
  local owner_write=${perms:2:1}
  if [[ "$owner_read" != "r" || "$owner_write" != "w" ]]; then
    error "Directory mode does not grant owner read/write: $dir"
    return 1
  fi
  if $VERBOSE; then
    info "Verified read/write permissions on $dir"
  fi
}

ensure_dir_exists() {
  local dir="$1"
  if $DRY_RUN; then
    info "[dry-run] Would ensure directory exists: $dir"
    return 0
  fi
  mkdir -p "$dir"
  assert_dir_permissions "$dir"
}

relative_backup_path() {
  local path="$1"
  if [[ "$path" == "$HOME"* ]]; then
    echo "${path#$HOME/}"
  else
    echo "${path#/}"
  fi
}

backup_target() {
  local target="$1"
  local rel_path
  rel_path=$(relative_backup_path "$target")
  BACKUP_TIMESTAMP=${BACKUP_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}
  local destination="$BACKUP_ROOT/$BACKUP_TIMESTAMP/$rel_path"
  if $DRY_RUN; then
    info "[dry-run] Would move existing $target to $destination"
    return 0
  fi
  mkdir -p "$(dirname "$destination")"
  mv "$target" "$destination"
  info "Backed up $target to $destination"
}

handle_existing_target() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    if $FORCE; then
      if $DRY_RUN; then
        info "[dry-run] Would remove existing $target"
      else
        rm -rf "$target"
        info "Removed existing $target"
      fi
    else
      backup_target "$target"
    fi
  fi
}

install_file() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || { error "Missing source file: $src"; return 1; }
  local dest_dir
  dest_dir="$(dirname "$dest")"
  ensure_dir_exists "$dest_dir"
  handle_existing_target "$dest"
  if $DRY_RUN; then
    info "[dry-run] Would copy $src to $dest"
  else
    install -Dm644 "$src" "$dest"
    info "Installed file $dest"
  fi
}

install_directory() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || { error "Missing source directory: $src"; return 1; }
  if [[ -e "$dest" || -L "$dest" ]]; then
    handle_existing_target "$dest"
  fi
  ensure_dir_exists "$dest"
  if $DRY_RUN; then
    info "[dry-run] Would sync directory $src to $dest"
  else
    mkdir -p "$dest"
    assert_dir_permissions "$dest"
    local docs_filter='**/*docs*/'
    rsync -a --delete --exclude "$docs_filter" "$src"/ "$dest"/
    info "Installed directory $dest"
  fi
  assert_dir_permissions "$dest"
}

process_plan() {
  build_install_plan
  for entry in "${INSTALL_PLAN[@]}"; do
    IFS='|' read -r kind src dest <<<"$entry"
    case "$kind" in
      file) install_file "$src" "$dest" ;;
      dir) install_directory "$src" "$dest" ;;
      *) error "Unknown plan entry type: $kind"; return 1 ;;
    esac
  done
}

check_dependencies() {
  $SKIP_PACKAGES && return 0
  local missing=()
  for bin in "${REQUIRED_BINS[@]}"; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      missing+=("$bin")
    fi
  done
  if ((${#missing[@]})); then
    warn "Missing dependencies: ${missing[*]}"
    local prompt_message="Missing dependencies detected. Continue anyway?"
    info "$prompt_message"
    if prompt_yes_no "$prompt_message"; then
      info "Proceeding despite missing dependencies"
    else
      error "Aborted due to missing dependencies"
      return 1
    fi
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --force) FORCE=true ;;
      --skip-packages) SKIP_PACKAGES=true ;;
      --backup-dir) shift; BACKUP_ROOT="$1" ;;
      --verbose) VERBOSE=true ;;
      --yes|-y) ASSUME_YES=true ;;
      --print-plan) PRINT_PLAN=true ;;
      --help) usage; exit 0 ;;
      *) error "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  if $PRINT_PLAN; then
    print_install_plan
    exit 0
  fi
  check_dependencies
  process_plan
  info "Setup complete"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
