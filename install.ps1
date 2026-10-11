# Installs the ship-task skill and the exact (pinned) versions of the skills it calls.
#
#   irm https://raw.githubusercontent.com/Koushik890/ship-task/main/install.ps1 | iex
#   .\install.ps1                     # from a clone
#
# Env overrides:
#   CLAUDE_SKILLS_DIR  install target (default: ~/.claude/skills)
#   SHIP_TASK_REF      branch/tag/sha of ship-task to install when run via irm (default: main)
# Works on Windows PowerShell 5.1 and PowerShell 7+.

& {
$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/Koushik890/ship-task'
$Ref = if ($env:SHIP_TASK_REF) { $env:SHIP_TASK_REF } else { 'main' }
$SkillsDir = if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $HOME '.claude/skills' }

function Test-Command($Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed" }
}

if (-not (Test-Command git)) { throw 'git is required.' }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('ship-task-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work | Out-Null

try {
    # Source of ship-task itself: the clone this script sits in, or a fresh fetch.
    $ScriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
    if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir 'SKILL.md')) -and (Test-Path (Join-Path $ScriptDir 'deps.lock'))) {
        $Src = $ScriptDir
    } else {
        $Src = Join-Path $Work 'ship-task'
        Invoke-Git clone -q $RepoUrl $Src
        Invoke-Git -C $Src -c advice.detachedHead=false checkout -q $Ref
    }

    New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null

    # Replace $SkillsDir\<name> with the contents of $From. Never touches a git checkout.
    function Install-SkillDir($Name, $From) {
        $Dest = Join-Path $SkillsDir $Name
        if (-not (Test-Path (Join-Path $From 'SKILL.md'))) { throw "${Name}: no SKILL.md in source" }
        $item = Get-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue
        if ($item) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                # Symlink/junction from an earlier `npx skills` install: remove the link, not its target.
                [IO.Directory]::Delete($item.FullName)
            } elseif (Test-Path (Join-Path $Dest '.git')) {
                Write-Warning "${Name}: $Dest is a git checkout, leaving it alone (git pull it to update)"
                return
            } else {
                Remove-Item -LiteralPath $Dest -Recurse -Force
            }
        }
        New-Item -ItemType Directory -Path $Dest | Out-Null
        Get-ChildItem -LiteralPath $From -Force | Where-Object { $_.Name -ne '.git' } |
            Copy-Item -Destination $Dest -Recurse -Force
        Write-Host "  $Name"
    }

    # Fetch one commit of a repo (shallow); later skills from the same commit reuse it.
    $Repos = @{}
    function Get-PinnedCommit($Url, $Sha) {
        if ($Repos.ContainsKey($Sha)) { return $Repos[$Sha] }
        $Dir = Join-Path $Work "repos/$Sha"
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        Invoke-Git -C $Dir init -q
        Invoke-Git -C $Dir fetch -q --depth 1 $Url $Sha
        Invoke-Git -C $Dir -c advice.detachedHead=false checkout -q FETCH_HEAD
        $got = (& git -C $Dir rev-parse HEAD | Out-String).Trim()
        if ($got -ne $Sha) { throw "${Url}: got wrong commit $got" }
        $Repos[$Sha] = $Dir
        return $Dir
    }

    Write-Host "Installing into $SkillsDir"

    # ship-task itself: only the files the skill needs at runtime.
    $Stage = Join-Path $Work 'stage-ship-task'
    New-Item -ItemType Directory -Path $Stage | Out-Null
    foreach ($f in 'SKILL.md', 'LICENSE', 'deps.lock') { Copy-Item (Join-Path $Src $f) $Stage }
    Install-SkillDir 'ship-task' $Stage

    foreach ($line in Get-Content (Join-Path $Src 'deps.lock')) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $name, $url, $sha, $path = $line.Split('|')
        $repo = Get-PinnedCommit $url $sha
        Install-SkillDir $name (Join-Path $repo $path)
    }

    # Tool checks: warn only. Optional tools only disable the steps that need them.
    Write-Host ''
    Write-Host 'Checking tools:'
    function Show-Tool($Name, $Hint) {
        if (Test-Command $Name) { Write-Host "  ok       $Name" } else { Write-Host "  missing  $Name  ($Hint)" }
    }
    if (Test-Command gh) {
        $m = [regex]::Match((& gh --version | Select-Object -First 1), '(\d+)\.(\d+)')
        $maj = [int]$m.Groups[1].Value; $min = [int]$m.Groups[2].Value
        if ($maj -gt 2 -or ($maj -eq 2 -and $min -ge 100)) { Write-Host "  ok       gh $maj.$min" }
        else { Write-Host "  old      gh $maj.$min  (need 2.100+ for PR media uploads: upgrade gh)" }
        $null = cmd /c 'gh auth status >nul 2>&1'
        if ($LASTEXITCODE -ne 0) { Write-Host "           gh is not logged in: run 'gh auth login'" }
    } else {
        Write-Host "  missing  gh  (required: winget install GitHub.cli, then 'gh auth login')"
    }
    Show-Tool node 'required by before-and-after: winget install OpenJS.NodeJS.LTS'
    Show-Tool jq 'used by greploop: winget install jqlang.jq'
    if ((Test-Command python3) -or (Test-Command python) -or (Test-Command py)) { Write-Host '  ok       python' }
    else { Write-Host '  missing  python  (evidence recorder: winget install Python.Python.3.12)' }
    Show-Tool ffmpeg 'evidence screen recordings: winget install Gyan.FFmpeg'
    Show-Tool agent-browser 'UI captures: npm i -g agent-browser'

    Write-Host ''
    Write-Host 'Done. Restart Claude Code, then run: /ship-task <task description>'
}
finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
}
