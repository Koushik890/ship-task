# ship-task

A Claude Code skill that runs one task from idea to pull request:

1. **Isolate**: new git worktree from latest `origin/main` (`/new-feature`)
2. **Build**: smallest change that does the task (`/code-structure`)
3. **Prove**: before/after evidence plus the repo's checks (`/evidence-driven-testing`)
4. **Ship**: commit, push, PR with before/after media (`/before-and-after`, `/unslop`), then loop Greptile to 5/5 (`/greploop`)

Usage inside Claude Code:

```
/ship-task <task description>
```

## Install

### Option 1: install script (skill + all dependencies)

macOS / Linux / Git Bash:

```bash
curl -fsSL https://raw.githubusercontent.com/Koushik890/ship-task/main/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/Koushik890/ship-task/main/install.ps1 | iex
```

Both scripts need Node.js (for `npx`). They install globally for Claude Code:

- `Koushik890/ship-task` (this skill)
- `michaelshimeles/skills`: `new-feature`, `code-structure`, `evidence-driven-testing`, `unslop`, `greploop`, `greploop-apps`
- `vercel-labs/before-and-after`

### Option 2: manual with the `skills` CLI

```bash
npx skills add Koushik890/ship-task -g -a claude-code -y
npx skills add michaelshimeles/skills -g -a claude-code -y -s new-feature -s code-structure -s evidence-driven-testing -s unslop -s greploop -s greploop-apps
npx skills add vercel-labs/before-and-after -g -a claude-code -y
```

### Option 3: git clone

```bash
git clone https://github.com/Koushik890/ship-task ~/.claude/skills/ship-task
```

Then install the dependency skills with the commands from option 2. To update later: `git -C ~/.claude/skills/ship-task pull`.

## Other requirements

- `git` and the GitHub CLI `gh`, logged in (`gh auth login`). gh 2.100+ for `/before-and-after` uploads.
- [`agent-browser`](https://github.com/vercel-labs/agent-browser) for before/after screenshots of UI changes (`npm i -g agent-browser`).
- The [Greptile](https://greptile.com) GitHub app on the target repo for the review loop. Without it, that step is skipped.

Restart Claude Code after installing so it picks up the new skills.

## License

MIT
