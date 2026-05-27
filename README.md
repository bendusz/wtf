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
source ~/.zshrc   # or ~/.bashrc
```

## Usage

```bash
wtf            # explain the last command
wtf --fix      # also propose a fix and prompt to run it
```

`--fix` makes Claude emit a single fix command in a fenced block. `wtf`
parses it out and asks `[y/N]` before running anything.

## How it works

1. Grabs the previous command from history with `fc -ln`.
2. Re-runs it to capture stdout, stderr, and the exit code.
3. Pipes everything to `claude -p` for an explanation.
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
- Only the last command on the history line is considered. Pipelines and
  multi-statement lines are sent verbatim.

## Uninstall

```bash
rm -rf ~/.wtf
```

Then remove the `source ~/.wtf/wtf.sh` line from your shell rc file.

## License

MIT — see [LICENSE](LICENSE).
