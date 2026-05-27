#!/usr/bin/env bash
# wtf installer — fetches wtf.sh and wires it into your shell rc.
# Usage: curl -fsSL https://raw.githubusercontent.com/bendusz/wtf/main/install.sh | bash
set -euo pipefail

REPO="bendusz/wtf"
BRANCH="${WTF_BRANCH:-main}"
INSTALL_DIR="${WTF_INSTALL_DIR:-$HOME/.wtf}"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/wtf.sh"

err() { printf 'wtf-install: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }

if ! command -v curl >/dev/null 2>&1; then
    err "curl is required but not found."
    exit 1
fi

mkdir -p "$INSTALL_DIR"

info "Downloading wtf.sh from $SCRIPT_URL ..."
if ! curl -fsSL "$SCRIPT_URL" -o "${INSTALL_DIR}/wtf.sh"; then
    err "Failed to download wtf.sh"
    exit 1
fi

detect_rc() {
    local shell_name
    shell_name="$(basename "${SHELL:-bash}")"
    case "$shell_name" in
        zsh)
            printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc"
            ;;
        bash)
            if [[ "$(uname -s)" == "Darwin" && -f "$HOME/.bash_profile" ]]; then
                printf '%s\n' "$HOME/.bash_profile"
            elif [[ -f "$HOME/.bashrc" ]]; then
                printf '%s\n' "$HOME/.bashrc"
            elif [[ "$(uname -s)" == "Darwin" ]]; then
                printf '%s\n' "$HOME/.bash_profile"
            else
                printf '%s\n' "$HOME/.bashrc"
            fi
            ;;
        *)
            printf '%s\n' "$HOME/.profile"
            ;;
    esac
}

RC_FILE="$(detect_rc)"
touch "$RC_FILE"

SOURCE_LINE="[ -f \"${INSTALL_DIR}/wtf.sh\" ] && source \"${INSTALL_DIR}/wtf.sh\""

if grep -Fq "${INSTALL_DIR}/wtf.sh" "$RC_FILE"; then
    info "Already wired into $RC_FILE — skipping."
else
    {
        printf '\n# wtf — explain the last command (https://github.com/%s)\n' "$REPO"
        printf '%s\n' "$SOURCE_LINE"
    } >> "$RC_FILE"
    info "Added wtf source line to $RC_FILE"
fi

if ! command -v claude >/dev/null 2>&1; then
    printf '\n⚠  Warning: "claude" CLI not found in PATH.\n'
    printf '   Install Claude Code: https://claude.com/claude-code\n'
fi

cat <<EOF

✓ Installed wtf to ${INSTALL_DIR}/wtf.sh

To start using it now:
  source ${RC_FILE}

Then try:
  ls /nonexistent
  wtf
  wtf --fix
EOF
