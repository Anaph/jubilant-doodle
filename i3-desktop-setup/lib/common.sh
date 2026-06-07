# shellcheck shell=bash
#
# common.sh — shared helpers for the i3-desktop-setup installer.
#
# This file is meant to be *sourced*, never executed directly. It provides
# logging, privilege handling, and idempotent file/package helpers that every
# step under steps/ relies on.
#
# Callers are expected to have exported:
#   TARGET_USER  — the unprivileged user the desktop is installed for
#   TARGET_HOME  — that user's home directory (resolved from the passwd db)
#   REPO_DIR     — absolute path to the i3-desktop-setup/ directory

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

# Enable colours only when writing to a real terminal.
if [ -t 1 ]; then
    _C_RESET=$'\033[0m'
    _C_BLUE=$'\033[1;34m'
    _C_GREEN=$'\033[1;32m'
    _C_YELLOW=$'\033[1;33m'
    _C_RED=$'\033[1;31m'
    _C_DIM=$'\033[2m'
else
    _C_RESET='' _C_BLUE='' _C_GREEN='' _C_YELLOW='' _C_RED='' _C_DIM=''
fi

_timestamp() { date '+%H:%M:%S'; }

log_info()  { printf '%s[%s]%s %s\n'  "$_C_DIM"    "$(_timestamp)" "$_C_RESET" "$*"; }
log_ok()    { printf '%s[ ok ]%s %s\n' "$_C_GREEN"  "$_C_RESET" "$*"; }
log_warn()  { printf '%s[warn]%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_error() { printf '%s[err ]%s %s\n' "$_C_RED"    "$_C_RESET" "$*" >&2; }

# A prominent banner used between major steps.
log_step() {
    printf '\n%s==>%s %s%s%s\n' "$_C_BLUE" "$_C_RESET" "$_C_BLUE" "$*" "$_C_RESET"
}

# Log an error and abort.
die() { log_error "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Privilege handling
# ---------------------------------------------------------------------------

# Prime the sudo credential cache once, failing fast with a clear message if
# the invoking user has no sudo rights at all.
need_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        die "sudo is not installed but is required. Install it as root: apt-get install sudo"
    fi
    if ! sudo -v; then
        die "This step needs administrative rights, but 'sudo' failed for user '$(id -un)'."
    fi
}

# Run a command as $TARGET_USER with a correct HOME. When we are already that
# user (the normal case) the command runs directly; otherwise we drop down via
# sudo. Used for everything that writes into the user's $HOME.
run_as_user() {
    if [ "$(id -un)" = "$TARGET_USER" ]; then
        HOME="$TARGET_HOME" "$@"
    else
        sudo -u "$TARGET_USER" --set-home -- "$@"
    fi
}

# ---------------------------------------------------------------------------
# Idempotent file helpers
# ---------------------------------------------------------------------------

# Back up an existing regular file exactly once per run, preserving the original
# so uninstall.sh can restore it. No-op for files we do not need to protect.
backup_file() {
    local path="$1"
    if [ -e "$path" ] && [ ! -L "$path" ]; then
        local backup
        backup="${path}.bak.$(date '+%Y%m%d-%H%M%S')"
        if [ ! -e "$backup" ]; then
            cp -a "$path" "$backup"
            log_info "Backed up existing $path -> $backup"
        fi
    fi
}

# install_config SRC DEST [MODE]
# Copy a shipped config file into the user's home: back up any existing file,
# create parent directories, set ownership to the target user.
install_config() {
    local src="$1" dest="$2" mode="${3:-0644}"
    [ -e "$src" ] || die "install_config: source '$src' does not exist"
    backup_file "$dest"
    run_as_user mkdir -p "$(dirname "$dest")"
    # Use a temp copy then move so ownership/mode are applied atomically.
    install -D -m "$mode" "$src" "$dest"
    chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$dest"
    log_info "Installed $dest"
}

# append_once FILE LINE
# Append LINE to FILE only if an identical line is not already present. Keeps
# PATH / profile edits free of duplicates across re-runs.
append_once() {
    local file="$1" line="$2"
    run_as_user mkdir -p "$(dirname "$file")"
    if [ ! -e "$file" ]; then
        run_as_user touch "$file"
    fi
    if ! run_as_user grep -qxF -- "$line" "$file"; then
        printf '%s\n' "$line" | run_as_user tee -a "$file" >/dev/null
        log_info "Appended to $file: $line"
    fi
}

# git_clone_idempotent URL DEST [BRANCH]
# Clone if absent; otherwise update an existing checkout with a fast-forward.
# Runs as the target user so the tree is owned correctly.
git_clone_idempotent() {
    local url="$1" dest="$2" branch="${3:-}"
    if [ -d "$dest/.git" ]; then
        log_info "Updating existing checkout: $dest"
        run_as_user git -C "$dest" fetch --quiet --depth 1 origin || \
            log_warn "git fetch failed for $dest (offline?); using existing checkout"
        if [ -n "$branch" ]; then
            run_as_user git -C "$dest" checkout --quiet "$branch" 2>/dev/null || true
        fi
        run_as_user git -C "$dest" pull --quiet --ff-only 2>/dev/null || \
            log_warn "git pull failed for $dest; using existing checkout"
    else
        run_as_user mkdir -p "$(dirname "$dest")"
        log_info "Cloning $url -> $dest"
        if [ -n "$branch" ]; then
            run_as_user git clone --quiet --depth 1 --branch "$branch" "$url" "$dest"
        else
            run_as_user git clone --quiet --depth 1 "$url" "$dest"
        fi
    fi
}

# pkg_install_from_manifest FILE [extra apt args...]
# Read a package manifest (one package per line, '#' comments and blank lines
# ignored) and install everything in a single apt transaction. apt is naturally
# idempotent, so re-running is safe.
pkg_install_from_manifest() {
    local manifest="$1"; shift
    [ -f "$manifest" ] || die "package manifest not found: $manifest"
    local pkgs=()
    local line
    while IFS= read -r line; do
        line="${line%%#*}"               # strip inline comments
        line="${line//[[:space:]]/}"     # strip surrounding whitespace
        [ -n "$line" ] && pkgs+=("$line")
    done <"$manifest"
    [ "${#pkgs[@]}" -gt 0 ] || die "no packages parsed from $manifest"
    log_info "Installing ${#pkgs[@]} packages from $(basename "$manifest")"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" "${pkgs[@]}"
}

# ---------------------------------------------------------------------------
# Package-system recovery
# ---------------------------------------------------------------------------

# Temporarily turn update-initramfs into a no-op so a package whose initramfs
# trigger is currently failing can still be removed. Paired with _initramfs_on.
_initramfs_off() {
    if ! dpkg-divert --list /usr/sbin/update-initramfs 2>/dev/null | grep -q update-initramfs; then
        sudo dpkg-divert --add --rename --divert /usr/sbin/update-initramfs.real \
            /usr/sbin/update-initramfs >/dev/null 2>&1 || true
    fi
    sudo ln -sf /bin/true /usr/sbin/update-initramfs
}

_initramfs_on() {
    sudo rm -f /usr/sbin/update-initramfs
    if dpkg-divert --list /usr/sbin/update-initramfs 2>/dev/null | grep -q update-initramfs; then
        sudo dpkg-divert --remove --rename /usr/sbin/update-initramfs >/dev/null 2>&1 || true
    fi
}

# Recover a half-configured dpkg state so apt can proceed. The usual culprit on
# Raspberry Pi / uConsole is Plymouth's update-initramfs trigger failing; since
# Plymouth is only a boot splash, removing it unblocks the install. Acts only
# when dpkg is actually broken — a no-op on a healthy system.
heal_dpkg() {
    local log="/tmp/i3ds-dpkg-heal.log"
    if sudo dpkg --configure -a 2>"$log"; then
        return 0
    fi
    log_warn "Package system is half-configured — attempting automatic repair…"
    if grep -qiE 'plymouth|initramfs' "$log"; then
        log_info "Cause looks like Plymouth/initramfs (common on Pi). Removing Plymouth (boot splash, not needed)."
        if ! sudo apt-get purge -y 'plymouth*' >/dev/null 2>&1; then
            # The purge itself is blocked by the broken trigger — neutralise it.
            _initramfs_off
            sudo apt-get purge -y 'plymouth*' >/dev/null 2>&1 || true
            sudo dpkg --configure -a >/dev/null 2>&1 || true
            _initramfs_on
            sudo update-initramfs -u >/dev/null 2>&1 || \
                log_warn "initramfs rebuild still failing (check /boot/firmware free space); Plymouth removed, continuing."
        fi
        sudo dpkg --configure -a >/dev/null 2>&1 || true
    fi
    if sudo dpkg --configure -a >/dev/null 2>&1; then
        log_ok "Package system recovered"
    else
        log_error "Automatic repair did not finish. Run this and share the output:"
        log_error "  sudo dpkg --configure -a"
        die "dpkg is still half-configured"
    fi
}
