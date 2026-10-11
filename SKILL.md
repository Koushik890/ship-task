---
name: ship-task
description: Run the full michaelshimeles workflow on one task, start to PR - isolate in a worktree, build, prove with evidence, open a PR with before/after proof, then loop Greptile to 5/5. Invoke with /ship-task <task description>.
disable-model-invocation: true
argument-hint: <task description>
---

# Ship Task

Task: **$ARGUMENTS**

If the task is empty or too vague to test, ask one short question before starting.

Run the four beats below in order, invoking each named skill with the Skill tool. Do not skip a beat silently: if a beat cannot run (missing tool, no GUI, no Greptile), say so in one line, use the fallback, and keep going. Keep a short checklist of beats and tick each one off as you go.

## 0. Preflight

- Must be inside a git repo with a GitHub `origin` and an authenticated `gh` (`gh auth status`). If not, stop and tell the user what is missing.
- The skills this workflow calls must be installed: `new-feature`, `code-structure`, `evidence-driven-testing`, `unslop`, `greploop`, `greploop-apps`, `before-and-after`. If any is missing from your skill list, stop and tell the user to run the installer from https://github.com/Koushik890/ship-task. Do not improvise a replacement for a missing skill. The `before-and-after` skill must be the vercel-labs version: its directory contains `scripts/format.mjs`. If it has `scripts/capture.sh` instead, it is the older copy vendored in michaelshimeles/skills, which this workflow does not support; tell the user to rerun the installer.
- Find the default branch with `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fall back to `main`). Wherever this skill says `origin/main`, use `origin/<default branch>`.
- Check optional tools once and remember which are missing: `jq`, `node`, `ffmpeg`, `agent-browser`, and Python. On Windows `python3` is often absent or a Microsoft Store stub; try `python3`, then `python`, then `py -3`, and use whichever prints a 3.x version for every Python command the other skills give you.
- Shell: write commands for the shell tool you are actually running (bash/Git Bash vs PowerShell). Use forward slashes and quote paths that can contain spaces.
- Find the repo's checks: `CLAUDE.md` / `AGENTS.md` first, then `package.json` scripts (test, lint, typecheck, build), `Makefile`, `pyproject.toml`, etc. Note the exact commands; you will run them in beat 3 and before pushing.

## 1. Isolate - `/new-feature`

Start the task in its own worktree branched from latest `origin/main` (or the repo's default branch), including the scope check against open PRs. On overlap with another open PR, stop and ask.

## 2. Build - `/code-structure`

Implement the smallest change that does the task. Follow code-structure: actions own the why/when, a service layer owns reusable how. Do not refactor beyond what the task needs.

## 3. Prove - `/evidence-driven-testing`

- Capture the **before** state first, while reproducing the issue or showing the missing feature, before the fix lands where possible.
- Run the repo's checks from preflight; all must pass.
- Gather runtime evidence of the **after** state. UI change: screen recording if a GUI is drivable, else the skill's headless path (Playwright screenshots). Non-UI change: measured numbers or before/after output pairs.

## 4. Ship - `/before-and-after`, `/unslop`, `/greploop`

1. Commit with a clear message, rebase onto latest `origin/<default branch>`, rerun checks, push (`git push -u origin <branch>`; `--force-with-lease` only on your own branch, never plain `--force`).
2. Write the PR body: what changed, how it was tested (every claim backed by evidence), risks and follow-ups. Run `/unslop` over the PR title, body and commit messages, then open the PR with `gh pr create`.
3. Visible change: capture before/after screenshots or recordings with `agent-browser` (run `agent-browser skills get core --full` for usage) into a `captures/` folder, then run `/before-and-after` to insert the comparison block into the PR. Its formatter is `scripts/format.mjs` inside the before-and-after skill's own directory (the skill's base directory is shown when it loads; do not assume `~/.claude/skills`), run with `node`; it uploads through `gh --attach` (GitHub-hosted, needs gh 2.100+). Never commit `captures/`: add `captures/` to `.git/info/exclude` before capturing.
4. Run `/greploop` until Greptile gives 5/5 with zero unresolved comments (use `/greploop-apps` if Greptile says too many files changed). If Greptile is not installed on the repo or never responds, say so and skip this step.

## Finish

- **Do not merge** the PR unless the user explicitly says to.
- Keep the worktree until the PR is merged or closed.
- End with: PR URL, one line per beat (done / skipped and why), and the Greptile score.
