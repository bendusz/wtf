#!/usr/bin/env bash
# wtf installer — fetches wtf.sh and wires it into your shell rc.
# Usage: curl -fsSL https://raw.githubusercontent.com/bendusz/wtf/main/install.sh | bash
#
# Optional environment variables:
#   WTF_BRANCH        ref to install (branch, tag, or commit sha). Default: main
#   WTF_INSTALL_DIR   target dir for wtf.sh. Default: $HOME/.wtf
#   WTF_SHA256        if set, verify the downloaded wtf.sh against this hex digest
set -euo pipefail

REPO="bendusz/wtf"
BRANCH="${WTF_BRANCH:-main}"
INSTALL_DIR="${WTF_INSTALL_DIR:-$HOME/.wtf}"
WTF_SHA256="${WTF_SHA256:-}"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/wtf.sh"

err()  { printf 'wtf-install: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }

# Single-quote escape: turn  a'b  into  'a'\''b'  so the path can be embedded
# inside single-quoted shell code without any chance of breaking out.
sq() {
    local s=$1
    printf "'%s'" "${s//\'/\'\\\'\'}"
}

case "$INSTALL_DIR" in
    *$'\n'*|*$'\r'*)
        err "WTF_INSTALL_DIR must not contain newlines."
        exit 1
        ;;
esac

if ! command -v curl >/dev/null 2>&1; then
    err "curl is required but not found."
    exit 1
fi

mkdir -p "$INSTALL_DIR"

sha256_of() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        return 1
    fi
}

info "Downloading wtf.sh from $SCRIPT_URL ..."
TMP="${INSTALL_DIR}/.wtf.sh.download.$$"
trap 'rm -f "$TMP"' EXIT
if ! curl -fsSL "$SCRIPT_URL" -o "$TMP"; then
    err "Failed to download wtf.sh from $SCRIPT_URL"
    exit 1
fi

# Make sure we didn't just write a truncated/garbage file. bash parsing the
# script is a cheap sanity check before it ever gets sourced.
if ! bash -n "$TMP" 2>/dev/null; then
    err "Downloaded wtf.sh failed bash syntax check (truncated or wrong file?)"
    exit 1
fi

if [[ -n "$WTF_SHA256" ]]; then
    if ! actual_sha=$(sha256_of "$TMP"); then
        err "WTF_SHA256 is set but neither shasum nor sha256sum is available."
        exit 1
    fi
    if [[ "$actual_sha" != "$WTF_SHA256" ]]; then
        err "checksum mismatch: expected $WTF_SHA256, got $actual_sha"
        exit 1
    fi
    info "Checksum OK ($actual_sha)"
fi

# Atomic install: only swap into place after the download passed validation.
mv "$TMP" "${INSTALL_DIR}/wtf.sh"
trap - EXIT

detect_rc() {
    local shell_name os
    shell_name="$(basename "${SHELL:-bash}")"
    os="$(uname -s)"
    case "$shell_name" in
        zsh)
            printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc"
            ;;
        bash)
            # macOS login bash reads ~/.bash_profile, NOT ~/.bashrc, so on
            # Darwin we always pick .bash_profile (creating it if necessary).
            if [[ "$os" == "Darwin" ]]; then
                printf '%s\n' "$HOME/.bash_profile"
            else
                printf '%s\n' "$HOME/.bashrc"
            fi
            ;;
        *)
            # Unknown shell — caller decides what to do.
            printf '%s\n' ""
            ;;
    esac
}

RC_FILE="$(detect_rc)"
QUOTED=$(sq "${INSTALL_DIR}/wtf.sh")
# Use POSIX `.` (not `source`) and guard so this is a no-op in non-bash/zsh
# shells that happen to source the same rc file (or ~/.profile fallbacks).
SOURCE_LINE="if [ -n \"\$BASH_VERSION\" ] || [ -n \"\$ZSH_VERSION\" ]; then [ -f ${QUOTED} ] && . ${QUOTED}; fi"

if [[ -z "$RC_FILE" ]]; then
    cat >&2 <<EOF
wtf-install: unsupported shell "$(basename "${SHELL:-?}")".
wtf requires bash or zsh. wtf.sh was installed at ${INSTALL_DIR}/wtf.sh,
but no rc file was modified. To enable wtf in a compatible shell, add:

    ${SOURCE_LINE}

EOF
    exit 0
fi
touch "$RC_FILE"

MARKER_BEGIN="# >>> wtf install (https://github.com/${REPO}) >>>"
MARKER_END="# <<< wtf install <<<"

if grep -Fxq "$MARKER_BEGIN" "$RC_FILE" 2>/dev/null; then
    info "Already wired into $RC_FILE — skipping. Remove the marker block to re-wire."
else
    {
        printf '\n%s\n' "$MARKER_BEGIN"
        printf '%s\n' "$SOURCE_LINE"
        printf '%s\n' "$MARKER_END"
    } >> "$RC_FILE"
    info "Added wtf source block to $RC_FILE"
fi

if ! command -v claude >/dev/null 2>&1; then
    printf '\n⚠  Warning: "claude" CLI not found in PATH.\n'
    printf '   Install Claude Code: https://claude.com/claude-code\n'
fi

cat <<EOF

✓ Installed wtf to ${INSTALL_DIR}/wtf.sh
✓ Wired source block into ${RC_FILE}

To start using it now:
  source "${RC_FILE}"

Then try:
  ls /nonexistent
  wtf
  wtf --fix

To pin a version next time:
  WTF_BRANCH=<tag-or-commit-sha> WTF_SHA256=<hex> \\
    curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash
EOF
