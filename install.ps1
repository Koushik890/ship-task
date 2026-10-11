# Installs the ship-task skill and the skills it calls, globally for Claude Code.
$ErrorActionPreference = 'Stop'

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Error 'npx not found. Install Node.js first: https://nodejs.org'
    return
}

function Add-Skill {
    param([string[]]$SkillArgs)
    & npx -y skills add @SkillArgs -g -a claude-code -y
    if ($LASTEXITCODE -ne 0) { throw "skills add $($SkillArgs -join ' ') failed" }
}

Add-Skill @('Koushik890/ship-task')
Add-Skill @('michaelshimeles/skills',
    '-s', 'new-feature', '-s', 'code-structure', '-s', 'evidence-driven-testing',
    '-s', 'unslop', '-s', 'greploop', '-s', 'greploop-apps')
Add-Skill @('vercel-labs/before-and-after')

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Note: GitHub CLI (gh) not found. Install it and run 'gh auth login'."
}
if (-not (Get-Command agent-browser -ErrorAction SilentlyContinue)) {
    Write-Host 'Note: agent-browser not found. For UI captures: npm i -g agent-browser'
}

Write-Host 'Done. Restart Claude Code, then run: /ship-task <task description>'
