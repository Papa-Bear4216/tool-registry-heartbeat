# Daily feature-gap review — runs headless Claude Code, one registry entry per day.
# Only proceeds if Pieces OS is running (consistent with the heartbeat's dependency).

param(
    [string]$RegistryPath = "$PSScriptRoot\tool_registry.example.md",
    [string]$LogPath = "$PSScriptRoot\feature-gap-log.txt"
)

$piecesRunning = Get-Process -Name "pieces_for_x" -ErrorAction SilentlyContinue
if (-not $piecesRunning) {
    exit 0
}

$prompt = @"
Underutilized-features check (slow cadence, runs once daily, unattended/headless). Read $RegistryPath.

Pick the ONE entry that has gone longest without a "Feature-gap reviewed: <date>" marker in its notes (or if none have ever been checked, start with the first entry under the first section). Skip entries still marked "needs review" with no confirmed active status.

Use WebSearch to research that tool/service's current feature set. Cross-reference against the entry's Observed lines and known usage from the file to find 1-3 specific, concrete, low-effort features that are plausibly unused, and would reduce risk, cost, or manual toil.

Do not suggest things already reflected in Observed lines or trigger text as in-use. Edit $RegistryPath to append the findings as a nested sub-bullet under that entry: "Feature-gap reviewed <date>: <1-3 short findings, or 'none found - already well-utilized'>". Keep it brief (under 300 chars total).

Do not notify. This is a silent, registry-only update. Do not touch any other entries this cycle.
"@

$claudeArgs = @(
    "-p", $prompt,
    "--allowedTools", "Read,Edit($RegistryPath),WebSearch"
)

$output = & claude @claudeArgs 2>&1 | Out-String

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $LogPath -Value "[$timestamp] $output`n---END---"
