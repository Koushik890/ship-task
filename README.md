# ship-task

A Claude Code skill that takes one task from idea to pull request:

1. **Isolate**: new git worktree from the latest default branch (`/new-feature`)
2. **Build**: smallest change that does the task (`/code-structure`)
3. **Prove**: before/after evidence plus the repo's own checks (`/evidence-driven-testing`)
4. **Ship**: commit, push, PR with before/after media (`/before-and-after`, `/unslop`), then loop Greptile to 5/5 (`/greploop`)

```
/ship-task <task description>
```

## Install

macOS / Linux / Git Bash:

```bash
curl -fsSL https://raw.githubusercontent.com/Koushik890/ship-task/main/install.sh | bash
```

Windows PowerShell (5.1 or 7+):

```powershell
irm https://raw.githubusercontent.com/Koushik890/ship-task/main/install.ps1 | iex
```

Restart Claude Code afterwards. Only `git` is needed to install.

### What the installer does

- Copies `ship-task` and the seven skills it calls into `~/.claude/skills/` as real files (no symlinks, so Windows needs no admin or developer mode).
- Fetches every dependency at the **exact commit** pinned in [`deps.lock`](deps.lock), so every machine runs the same versions:

  | Skill | Source |
  |---|---|
  | new-feature, code-structure, evidence-driven-testing, unslop, greploop, greploop-apps | [michaelshimeles/skills](https://github.com/michaelshimeles/skills) |
  | before-and-after | [vercel-labs/before-and-after](https://github.com/vercel-labs/before-and-after) |

- Replaces older copies of those skills, including symlinks left by `npx skills add` (only the link is removed, not what it points to). A skill folder that is a git checkout is left alone.
- Checks the tools below and tells you what is missing. It never installs system tools itself.

Options (environment variables): `CLAUDE_SKILLS_DIR` to install somewhere else, `SHIP_TASK_REF` to install a specific tag or commit of this repo, e.g. `SHIP_TASK_REF=v1.0.0`.

### Tools the workflow uses

| Tool | Needed for | Without it |
|---|---|---|
| `git`, `gh` 2.100+ (logged in) | everything; PR media uploads | the skill stops at preflight |
| `node` | before-and-after formatter | no media block in the PR |
| `jq` | greploop | Greptile loop is unreliable |
| Python 3, `ffmpeg` | evidence screen recordings | headless screenshots instead |
| [`agent-browser`](https://github.com/vercel-labs/agent-browser) | before/after UI captures | no captures |
| [Greptile](https://greptile.com) app on the target repo | review loop | step is skipped |

## Updating

Run the install command again. To move a dependency to a newer upstream version, change its commit in `deps.lock`, test it, and push. CI installs on Linux, macOS and Windows (bash, Windows PowerShell 5.1 and PowerShell 7) on every push and weekly, so a pinned commit that disappears upstream gets caught.

## License

MIT for this repo. Dependency skills keep their own licenses and are downloaded from their sources, not redistributed here.
