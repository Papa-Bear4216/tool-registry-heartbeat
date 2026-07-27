# Tool Registry Heartbeat

A background system that watches what you're actually doing (via [Pieces](https://pieces.app) OS's local activity capture) and cross-references it against a personal registry of tools/services you own, so you get nudged toward tools you already have instead of duplicating effort or forgetting they exist.

Built as a prototype on Windows with Claude Code + the Pieces MCP server.

## What it does

1. **`tool_registry.md`** (you create your own from `tool_registry.example.md`) is a plain-markdown inventory: one entry per tool, with a purpose, a trigger condition ("use when..."), access info, and a growing list of dated `Observed:` lines recording real usage.
2. **`heartbeat-wrapper.ps1`** runs on a timer (default: every 45 minutes, via Task Scheduler). Each run:
   - Queries Pieces for recent activity (`ask_pieces_ltm` / `workstream_summaries_full_text_search`).
   - Logs real, dated observations against matching registry entries.
   - Adds newly-discovered tools/services (capped at 2 per run, to avoid registry bloat from one big session).
   - Fires a Windows balloon-tip notification when activity matches a registry trigger you're not already using, or suggests a likely next tool based on an established pattern.
   - Optionally mirrors genuinely verified findings back into Pieces' own long-term memory via `create_pieces_memory` — never speculation, only concrete evidenced facts.
3. **`feature-gap-wrapper.ps1`** runs once daily. It picks one registry entry and does a real web-research pass on that tool's current feature set, looking for free/low-effort capabilities you're plausibly not using yet.

## Setup

1. Copy `tool_registry.example.md` to `tool_registry.md` and fill in your own tools.
2. Edit `heartbeat-wrapper.ps1` and `feature-gap-wrapper.ps1`'s default `$RegistryPath` if you don't want to pass it as a parameter every time (or just always call with `-RegistryPath "C:\path\to\your\tool_registry.md"`).
3. Make sure the [Pieces MCP server](https://docs.pieces.app/products/mcp/claude-code) is connected in Claude Code, and Pieces OS is running.
4. In an **elevated** PowerShell window:
   ```
   powershell -ExecutionPolicy Bypass -File register-heartbeat-task.ps1
   powershell -ExecutionPolicy Bypass -File register-feature-gap-task.ps1
   ```
5. Both scheduled tasks check whether Pieces OS (`pieces_for_x.exe`) is running and exit immediately if not — so they're safe to leave registered even when Pieces isn't active.

## Design notes and gotchas (learned the hard way)

- **Headless `claude -p` can refuse a prompt that describes itself as an "unattended background process."** Framing a prompt in the third person ("Background heartbeat, unattended run...") reads structurally like injected/untrusted content to the model, and it may decline to execute. Fix: use `--append-system-prompt` to establish legitimate first-party authorization ("you are a scheduled agent the user configured themselves..."), and write the task prompt itself in first person, describing the work directly rather than describing the process running it.
- **Don't rely on the model to reliably emit a literal trailing "done" sentinel line**, even with explicit, repeated instructions to do so — tested unreliable across many runs (the model would summarize, ask a follow-up question, or otherwise not end with the exact required string). Instead, check success mechanically in the wrapper script: process exit code plus whether the target file's mtime actually changed, or whether the output explicitly states no activity was found. This is far more robust than trusting output-formatting compliance from a single-turn run.
- **Multi-term `OR`'d keyword search against Pieces' `workstream_events_full_text_search` produced false negatives** — queries like `"chrome.exe OR msedge.exe OR WindowsTerminal.exe"` silently returned empty results even when matching events existed. Prefer `ask_pieces_ltm` with a plain-language question, or single-term (not `OR`'d) fallback queries.
- **`PushNotification`-style in-session tools won't reach you from a truly headless/unattended run** — they're scoped to the calling session's terminal/Remote-Control pairing. For anything that needs to survive logoff/reboot, use a real OS-level notification (this project uses `System.Windows.Forms.NotifyIcon` balloon tips, which work without any extra installed dependencies on Windows; `BurntToast`/native toast APIs are an alternative if you want richer visuals and don't mind the extra module).
- **Session-only schedulers (e.g. an in-chat cron-like tool) cannot survive a reboot, full stop** — there is no way around this other than moving to a real OS-level scheduler. Windows has no native "trigger on process start" — approximating it requires enabling machine-wide process-creation auditing (Event ID 4688), which is a heavier security-policy change than it's worth for this use case. A cheap equivalent: trigger at logon + a fixed repeat interval, and have the wrapper itself check whether the dependency process (e.g. Pieces OS) is running and exit immediately if not.
- **Cost**: an 8-minute cadence while attended is fine for prototyping/testing, but unattended and indefinite, it adds up fast — this project defaults to a slower 45-minute heartbeat and a once-daily feature-gap check specifically to keep background cost sane.
- **Privacy**: this pulls whatever Pieces has captured — which, depending on your Pieces configuration, may include screen OCR, clipboard, and audio transcripts. Be deliberate about what you're comfortable capturing and mirroring into Pieces LTM unattended; there's no human reviewing each cycle in real time the way there is when you're actively watching a session.

## Known limitations

- This is a prototype, not a polished product. The registry can grow unbounded over time with no automatic pruning/summarization step yet.
- Stray `claude.exe` processes have been observed not exiting promptly in some headless runs — worth periodically checking `tasklist` for orphaned processes if you notice memory creep.
- No dashboard/UI — `tool_registry.md`, `heartbeat-log.txt`, and `feature-gap-log.txt` are the only interfaces.
