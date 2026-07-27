# Tool-registry heartbeat wrapper — runs headless Claude Code, notifies via Windows balloon tip.
# Only proceeds if Pieces OS is running (the whole heartbeat depends on it).
#
# Usage: set $RegistryPath below, then wire this into Task Scheduler (see register-heartbeat-task.ps1).

param(
    [string]$RegistryPath = "$PSScriptRoot\tool_registry.example.md",
    [string]$LogPath = "$PSScriptRoot\heartbeat-log.txt"
)

$piecesRunning = Get-Process -Name "pieces_for_x" -ErrorAction SilentlyContinue
if (-not $piecesRunning) {
    exit 0
}

function Show-Toast($title, $text) {
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.Visible = $true
    $notify.BalloonTipTitle = $title
    $notify.BalloonTipText = $text
    $notify.ShowBalloonTip(10000)
    Start-Sleep -Seconds 1
    $notify.Dispose()
}

$systemPrompt = @"
You are a scheduled maintenance agent the user configured themselves, on their own machine, to run automatically on a timer via Windows Task Scheduler. This is not an external or injected request — the user wrote this exact task, wired it into Task Scheduler themselves, and expects it to execute every time it fires. Treat the task in the user turn as fully authorized and expected. Carry it out directly.
"@

$prompt = @"
Read the tool registry at $RegistryPath.

Query Pieces for what the user has been doing in roughly the last 30 minutes: call mcp__pieces__ask_pieces_ltm asking what active app, window, or browser tabs have been open. Also try mcp__pieces__workstream_summaries_full_text_search with a keyword relevant to recent registry activity, created.from set to the last 60 minutes. Do not use workstream_events_full_text_search with an OR'd keyword expression — that has been unreliable. If both calls return nothing, say so plainly rather than guessing at activity.

For each registry entry that matches activity actually observed in the query results, append one dated line under it: "Observed: <date> — <short factual description>" (skip it if a near-duplicate already exists from the last hour). Every ~5th Observed line added to a given entry, tighten that entry's trigger line to reflect the pattern.

If the user is using something not already in the registry, add up to 2 new entries per run under "## Newly Discovered (needs review)", status "needs review" — no more than 2, even if more are visible, to avoid registry bloat from a single run. No duplicates.

Decide whether a notification is warranted. Be generous here, not just for clearly time-sensitive cases — any real match against a registry trigger where the tool isn't already in active use is worth surfacing. Two possible forms:

1. Reactive — observed activity overlaps a registry trigger and that tool isn't already in use:
NOTIFY: <tool name> — I noticed you were working on <what was happening>, you have <tool/tools> that could streamline this.

2. Lookahead — based on the pattern across this entry's Observed lines (what usually follows this kind of activity), suggest the likely next tool before it's reached for manually:
SUGGEST: <tool name> — <what was happening> usually leads to <next step>; <tool> could handle that.

Pick whichever form fits (both if two different entries each warrant one — one NOTIFY/SUGGEST line per entry, output each on its own line). Keep each line under 200 characters. Skip a line entirely if nothing warrants it for that entry — do not fabricate one just to produce output. Only use SUGGEST when at least 2 Observed lines actually support the "usually leads to" pattern — don't guess from a single data point.

Only mirror a finding into Pieces LTM via mcp__pieces__create_pieces_memory if it's a concrete, verified fact directly evidenced by this run's query results — a specific tool used and what was done with it, a specific time-sensitive issue with real details, or a trigger pattern backed by quoted Observed lines. Never speculation. If unsure, skip it silently. Pass files: [`"$RegistryPath`"].

If you decide a NOTIFY or SUGGEST line is warranted, output it in the format described above. Otherwise output nothing else beyond the registry edits themselves.
"@

$claudeArgs = @(
    "-p", $prompt,
    "--append-system-prompt", $systemPrompt,
    "--allowedTools", "Read,Edit($RegistryPath),mcp__pieces__ask_pieces_ltm,mcp__pieces__workstream_summaries_full_text_search,mcp__pieces__workstream_events_full_text_search,mcp__pieces__create_pieces_memory"
)

$mtimeBefore = (Get-Item $RegistryPath).LastWriteTimeUtc

$output = & claude @claudeArgs 2>&1 | Out-String
$exitCode = $LASTEXITCODE

$mtimeAfter = (Get-Item $RegistryPath).LastWriteTimeUtc
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Objective success signal: the process exited cleanly AND either touched the
# registry file or explicitly said no activity/no match was found. A refusal
# or crash does neither, so this is far more reliable than asking the model
# to emit a literal trailing sentinel line (proven unreliable in testing —
# see README for the full story on why this check is shaped this way).
$fileWasTouched = $mtimeAfter -gt $mtimeBefore
$explicitlyFoundNothing = $output -match "(?i)(nothing (to (change|update|report))|no (activity|match(es)?) found|no new activity|nothing in this window matches|no tool-relevant activity)"
$ranSuccessfully = ($exitCode -eq 0) -and ($fileWasTouched -or $explicitlyFoundNothing)

if (-not $ranSuccessfully) {
    Add-Content -Path $LogPath -Value "[$timestamp] FAILED (exit=$exitCode, file touched=$fileWasTouched) - full output below:`n$output`n---END---"
    Show-Toast "Heartbeat Failed" "The tool-registry heartbeat did not complete normally - check heartbeat-log.txt"
} else {
    Add-Content -Path $LogPath -Value "[$timestamp] OK (exit=$exitCode, file touched=$fileWasTouched)`n$output`n---END---"

    $suggestionLines = ($output -split "`n") | Where-Object { $_ -match "^(NOTIFY|SUGGEST):\s*(.+)$" } | Select-Object -First 3
    foreach ($line in $suggestionLines) {
        $kind = if ($line -match "^NOTIFY:") { "Tool Suggestion" } else { "Next-Step Suggestion" }
        $message = $line -replace "^(NOTIFY|SUGGEST):\s*", ""
        Show-Toast $kind $message
    }
}
