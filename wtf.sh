# wtf — explain the last shell command using Claude.
# Source this file from your ~/.bashrc or ~/.zshrc.
# Repo: https://github.com/bendusz/wtf

wtf() {
    local fix_mode=0
    if [[ "${1:-}" == "--fix" || "${1:-}" == "-f" ]]; then
        fix_mode=1
        shift
    fi

    if ! command -v claude >/dev/null 2>&1; then
        printf 'wtf: "claude" CLI not found. Install Claude Code: https://claude.com/claude-code\n' >&2
        return 1
    fi

    # Grab the most recent command from history that isn't wtf itself.
    # Look back up to 10 entries so we skip past wtf invocations.
    local last_cmd
    last_cmd=$(fc -ln -10 -1 2>/dev/null | sed 's/^[[:space:]]*//' | awk '!/^wtf( |$)/ && NF' | tail -n1)

    if [[ -z "$last_cmd" ]]; then
        printf 'wtf: nothing in history to explain.\n' >&2
        return 1
    fi

    printf '↻ Re-running to capture output: %s\n\n' "$last_cmd"

    local output exit_code
    output=$(eval "$last_cmd" 2>&1)
    exit_code=$?

    local prompt
    prompt="I ran this command in my shell and want to understand what happened.

Command:
$last_cmd

Exit code: $exit_code

Output:
$output

Explain in one short paragraph what went wrong (or what the output means if exit code is 0) and how to fix it. Be specific and concrete. No preamble."

    if (( fix_mode )); then
        prompt+="

After your explanation, output the single best fix command in a fenced code block tagged 'fix', like this:
\`\`\`fix
the fix command here
\`\`\`
The fix block must contain exactly one shell command on a single line, with no comments or surrounding text."
    fi

    local response
    response=$(printf '%s\n' "$prompt" | claude -p)
    printf '%s\n' "$response"

    if (( fix_mode )); then
        local fix_cmd
        fix_cmd=$(printf '%s\n' "$response" \
            | awk '/^```fix[[:space:]]*$/{flag=1; next} /^```[[:space:]]*$/{flag=0} flag' \
            | head -n1)

        if [[ -z "$fix_cmd" ]]; then
            printf '\nwtf: no fix block found in response.\n' >&2
            return 0
        fi

        printf '\nRun fix? %s\n[y/N] ' "$fix_cmd"
        local ans
        read -r ans
        if [[ "$ans" =~ ^[Yy] ]]; then
            eval "$fix_cmd"
        else
            printf 'Skipped.\n'
        fi
    fi
}
