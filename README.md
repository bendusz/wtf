# wtf

Explain — and optionally fix — your last shell command using Claude.

```text
$ ls /nonexistent
ls: /nonexistent: No such file or directory
$ wtf
↻ Re-running to capture output: ls /nonexistent

The command failed because the path "/nonexistent" doesn't exist. List the
parent directory with `ls /` to see what's actually there, or create the
target with `mkdir -p /nonexistent` if that's what you intended.
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/bendusz/wtf/main/install.sh | bash
```

Restart your shell, or:

```bash
source ~/.zshrc   # or ~/.bash_profile / ~/.bashrc
```

### Pinning a version

For a real chain of custody, pin **both** `install.sh` and `wtf.sh` to the
same commit SHA and verify the `wtf.sh` digest. Env vars must be applied to
`bash` (after the pipe), not to `curl`:

```bash
SHA=<commit-sha>
curl -fsSL "https://raw.githubusercontent.com/bendusz/wtf/${SHA}/install.sh" \
  | WTF_BRANCH="$SHA" WTF_SHA256=<hex-digest-of-wtf.sh> bash
```

| Env var          | Purpose                                                    |
| ---------------- | ---------------------------------------------------------- |
| `WTF_BRANCH`     | Ref to fetch (branch / tag / commit sha). Default: `main`. |
| `WTF_INSTALL_DIR`| Where to drop `wtf.sh`. Default: `$HOME/.wtf`.             |
| `WTF_SHA256`     | Expected SHA-256 of `wtf.sh`. Aborts on mismatch.          |

## Usage

```bash
wtf                  # explain the last command
wtf --fix            # also propose a fix and prompt to run it
wtf --force-rerun    # re-run even if the command isn't on the safe allowlist
wtf --no-rerun       # never re-run; analyze the command text alone
```

Short flags: `-f` (`--fix`), `-y` (`--force-rerun`), `-n` (`--no-rerun`).

`--fix` asks Claude to emit a single fix command in a fenced block. `wtf`
parses it out and prompts `[y/N]` before running anything. Multi-line fix
blocks are rejected instead of silently truncated.

By default `wtf` checks the last command against a read-only allowlist
(`ls`, `cat`, `grep`, `git status`, `kubectl get`, `docker ps`, `curl` without
`-X POST`/`-d`, etc.). If the command isn't on the allowlist, you get a
three-way prompt: re-run anyway, skip the re-run and analyze the command
alone, or abort. Pipelines, multi-statement lines, redirections, command
substitutions, and `sudo` all force the prompt.

The classifier is a heuristic on literal history text. A wrapper script
(`./deploy.sh`) won't be classified and will prompt. An alias whose **name**
shadows an allowlisted command (e.g. `alias ls='rm -rf'`) will still auto-rerun,
because `wtf` sees the alias name in history, not its expansion. Same caveat
applies to shell functions. `awk` programs that shell out via `system()` or
pipe expressions are detected by string match — obfuscated forms can slip
through. Use `--no-rerun` if in doubt.

## How it works

1. Grabs the previous command from history with `fc -ln`.
2. Classifies it against a read-only allowlist. If safe, re-runs it to
   capture stdout, stderr, and the exit code. Otherwise prompts (or honors
   `--force-rerun`/`--no-rerun`).
3. Sends everything to `claude -p`, with any captured output wrapped in
   delimiters and an instruction to treat it as untrusted data.
4. With `--fix`: parses the fenced `fix` block and prompts before `eval`-ing it.

## Requirements

- macOS or Linux
- bash 3.2+ or zsh
- [`claude` CLI](https://claude.com/claude-code), authenticated
- `curl`

## Caveats

- **`wtf` may re-run the last command** to capture its real output. By
  default it only auto-reruns commands on a read-only allowlist; anything
  else (e.g. `rm`, `git reset --hard`, `curl -X POST`, opaque scripts) hits
  a three-way prompt first. `--force-rerun` skips the gate; `--no-rerun`
  disables re-execution entirely. The allowlist is heuristic — aliases and
  wrapper scripts (`./deploy.sh`) can't be classified and always prompt.
- **`--fix` runs `eval` on whatever Claude returns.** It prompts first, but
  always read the command before saying yes.
- Captured stderr is passed to Claude as **untrusted data**. The prompt
  tells Claude to ignore instructions inside it, but a determined
  prompt-injection payload may still influence the explanation — review
  any `--fix` suggestion accordingly.
- Only the last command on the history line is considered. Pipelines and
  multi-statement lines are sent verbatim.

## Uninstall

Remove the install directory (substitute your `WTF_INSTALL_DIR` if customized):

```bash
rm -rf ~/.wtf
```

Remove the marker block from whichever rc file the installer modified. The
installer prints the exact path at the end of its run — use that one:

```bash
RC=~/.zshrc            # zsh (macOS + Linux)
# RC=~/.bash_profile   # bash on macOS
# RC=~/.bashrc         # bash on Linux

# macOS / BSD sed:
sed -i '' '/# >>> wtf install/,/# <<< wtf install/d' "$RC"

# GNU sed (Linux):
sed -i '/# >>> wtf install/,/# <<< wtf install/d' "$RC"
```

Or open the rc file and delete everything between
`# >>> wtf install ... >>>` and `# <<< wtf install <<<`.

## License

MIT — see [LICENSE](LICENSE).
