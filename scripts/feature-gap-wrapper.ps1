# Daily feature-gap review - runs headless Claude Code, one registry entry per day.
# Only proceeds if Pieces OS is running (consistent with the heartbeat's dependency).

$piecesRunning = Get-Process -Name "pieces_for_x" -ErrorAction SilentlyContinue
if (-not $piecesRunning) {
    exit 0
}

# Adjust these two paths to match where your own Claude Code memory file
# lives, and where you want logs written.
$claudeHome = Join-Path $env:USERPROFILE ".claude"
$registryPath = Join-Path $claudeHome "projects\<your-project-folder>\memory\tool_registry.md"
$logPath = Join-Path $claudeHome "feature-gap-log.txt"

$prompt = @"
Underutilized-features check (slow cadence, runs once daily, unattended/headless). Read $registryPath.

Pick the ONE entry that has gone longest without a "Feature-gap reviewed: <date>" marker in its notes (or if none have ever been checked, start with the first entry under "## Dev / Infra"). Skip entries still marked "needs your input" with no confirmed active status.

Use WebSearch to research that tool/service's current feature set. Cross-reference against the entry's Observed lines and known usage from the file to find 1-3 specific, concrete, low-effort features the user is plausibly not using yet that would reduce risk, cost, or manual toil for their actual setup (describe your own real setup here in the entry's context, so the review has something concrete to check against - e.g. "a solo developer running a production web app on X hosting, Y database").

Do not suggest things already reflected in Observed lines or trigger text as in-use. Edit $registryPath to append the findings as a nested sub-bullet under that entry: "Feature-gap reviewed <date>: <1-3 short findings, or 'none found - already well-utilized'>". Keep it brief (under 300 chars total).

Do not notify. This is a silent, registry-only update. Do not touch any other entries this cycle.
"@

$claudeArgs = @(
    "-p", $prompt,
    "--allowedTools", "Read,Edit($registryPath),WebSearch"
)

$output = & claude @claudeArgs 2>&1 | Out-String

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logPath -Value "[$timestamp] $($output.Substring(0, [Math]::Min(500, $output.Length)))"
