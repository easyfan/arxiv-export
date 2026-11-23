# install.ps1 — arxiv-export Claude Code plugin installer (Windows/PowerShell)
# Usage:
#   .\install.ps1              # install to $env:USERPROFILE\.claude\
#   .\install.ps1 -DryRun      # preview without writing
#   .\install.ps1 -Uninstall   # remove installed files

param(
  [switch]$DryRun,
  [switch]$Uninstall,
  [string]$Target = ""
)

$ClaudeDir = if ($Target) { $Target } else { Join-Path $env:USERPROFILE ".claude" }
$ScriptDir = $PSScriptRoot

function Write-Ok   { param($msg) Write-Host "  v $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  - $msg (up to date)" -ForegroundColor DarkGray }
function Write-Warn { param($msg) Write-Host "  ! $msg" -ForegroundColor Yellow }

$SkillSrc = Join-Path $ScriptDir "skills\arxiv-export"
$SkillDst = Join-Path $ClaudeDir "skills\arxiv-export"

Write-Host ""
$version = (Get-Content (Join-Path $ScriptDir "package.json") | Select-String '"version"' | Select-Object -First 1) -replace '.*"version":\s*"([^"]+)".*','$1'
Write-Host "  arxiv-export — Claude Code plugin v$version"
Write-Host "  Target: $ClaudeDir"
if ($DryRun) { Write-Host "  Mode: DRY RUN (no files modified)" }
Write-Host ""

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-Warn "'claude' CLI not found. Install Claude Code first: https://claude.ai/code"
}
if ((-not (Get-Command tectonic -ErrorAction SilentlyContinue)) -and (-not (Get-Command pdflatex -ErrorAction SilentlyContinue))) {
  Write-Warn "No TeX engine found. The skill will offer to install one on first run."
}

if ($Uninstall) {
  if (Test-Path $SkillDst) {
    if (-not $DryRun) { Remove-Item -Recurse -Force $SkillDst }
    Write-Ok "Removed $SkillDst"
  } else {
    Write-Skip "$SkillDst (not found)"
  }
  Write-Host ""
  Write-Host "  Uninstall complete."
  Write-Host ""
  exit 0
}

$changed = 0
if ((Test-Path (Join-Path $SkillDst "SKILL.md")) -and `
    ((Get-FileHash (Join-Path $SkillSrc "SKILL.md")).Hash -eq (Get-FileHash (Join-Path $SkillDst "SKILL.md")).Hash)) {
  Write-Skip "skills\arxiv-export"
} else {
  if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $SkillDst | Out-Null
    Copy-Item -Recurse -Force (Join-Path $SkillSrc "*") $SkillDst
  }
  Write-Ok "skills\arxiv-export -> $SkillDst"
  $changed++
}

Write-Host ""
if ($DryRun) {
  Write-Host "  [dry-run] $changed file(s) would be modified."
} else {
  Write-Host "  Done! $changed file(s) installed."
  Write-Host ""
  Write-Host "  Quick start: in Claude Code, ask it to export your Markdown paper to an arXiv LaTeX submission."
}
Write-Host ""
