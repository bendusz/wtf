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

Install from a specific tag or commit with optional SHA-256 verification:

```bash
WTF_BRANCH=v1.0.0 \
WTF_SHA256=<hex-digest> \
  curl -fsSL https://raw.githubusercontent.com/bendusz/wtf/main/install.sh | bash
```

| Env var          | Purpose                                              |
| ---------------- | ---------------------------------------------------- |
| `WTF_BRANCH`     | Ref to fetch (branch / tag / commit sha). Default: `main` |
| `WTF_INSTALL_DIR`| Where to drop `wtf.sh`. Default: `$HOME/.wtf`       |
| `WTF_SHA256`     | Expected SHA-256 of `wtf.sh`. Aborts on mismatch.    |

## Usage

```bash
wtf            # explain the last command
wtf --fix      # also propose a fix and prompt to run it
```

`--fix` asks Claude to emit a single fix command in a fenced block. `wtf`
parses it out and prompts `[y/N]` before running anything. Multi-line fix
blocks are rejected instead of silently truncated.

## How it works

1. Grabs the previous command from history with `fc -ln`.
2. Re-runs it to capture stdout, stderr, and the exit code.
3. Sends everything to `claude -p`, with the captured output wrapped in
   delimiters and an instruction to treat it as untrusted data.
4. With `--fix`: parses the fenced `fix` block and prompts before `eval`-ing it.

## Requirements

- macOS or Linux
- bash 3.2+ or zsh
- [`claude` CLI](https://claude.com/claude-code), authenticated
- `curl`

## Caveats

- **`wtf` re-runs the last command** to capture its real output. Don't run
  it after destructive commands (`rm`, `git reset --hard`, network mutations,
  etc.) — you'll execute them twice.
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

Remove the marker block from your shell rc file:

```bash
# macOS / BSD sed:
sed -i '' '/# >>> wtf install/,/# <<< wtf install/d' ~/.zshrc

# GNU sed (Linux):
sed -i '/# >>> wtf install/,/# <<< wtf install/d' ~/.zshrc
```

Or open the rc file and delete everything between
`# >>> wtf install ... >>>` and `# <<< wtf install <<<`.

## License

MIT — see [LICENSE](LICENSE).
