# tool-registry-heartbeat

Two unattended Windows Scheduled Tasks that keep a `tool_registry.md` file (a
Claude Code memory file — an inventory of tools/services with usage triggers)
alive and evidence-based over time, without needing you to manually update it.

Both depend on [Pieces OS](https://pieces.app) running locally (for
`ask_pieces_ltm` / workstream search) and headless `claude -p` calls — no
interactive session required.

## What each one does

**`heartbeat-wrapper.ps1`** — runs every 45 minutes. Queries Pieces LTM for
recent activity, cross-references it against `tool_registry.md`'s trigger
conditions, and:
- appends a dated `Observed:` line to any entry that matches real activity
- adds up to 2 new "Newly Discovered" entries per run if it spots an unlisted
  tool/service in use
- decides whether a `NOTIFY:` (reactive — "I noticed you were doing X, tool Y
  could help") or `SUGGEST:` (lookahead — "this usually leads to Z, based on
  the pattern across N prior Observed lines") line is warranted, and fires a
  Windows toast if so

**`feature-gap-wrapper.ps1`** — runs once daily at 3:17 AM. Picks whichever
registry entry has gone longest without a "Feature-gap reviewed" note, web
searches that tool/service's current feature set, and appends 1-3 concrete,
low-effort feature suggestions relevant to your actual setup — silently, no
notification, registry-only.

## Setup

1. **Copy both wrapper scripts** into your own `%USERPROFILE%\.claude\`
   directory — Task Scheduler needs a stable path to invoke, and this repo is
   meant to be a version-controlled reference, not the live execution path.
2. **Edit `$registryPath`** near the top of each wrapper script to point at
   wherever your own `tool_registry.md` memory file actually lives (Claude
   Code's memory directory structure includes a project-specific folder name
   you'll need to fill in).
3. **Run both `register-*.ps1` scripts once**, in an **elevated** PowerShell
   window, to create the Scheduled Tasks:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "scripts\register-heartbeat-task.ps1"
powershell.exe -ExecutionPolicy Bypass -File "scripts\register-feature-gap-task.ps1"
```

Both register scripts assume the wrapper they register lives at
`%USERPROFILE%\.claude\<wrapper-name>.ps1` — adjust that path if you copied
the wrapper somewhere else.

**If you later edit a script in this repo, copy it back to your own
`%USERPROFILE%\.claude\` for the change to actually take effect** — Task
Scheduler always runs from that live path, never from wherever you cloned
this repo.

## Logs

`heartbeat-log.txt` and `feature-gap-log.txt` are written alongside the live
wrapper scripts in `%USERPROFILE%\.claude\` — not tracked in this repo (see
`.gitignore`), since they're constantly-growing runtime output, not source.

## Related

`tool_registry.md` itself is expected to live in your own Claude Code memory
directory, not in this repo — this repo only holds the automation that
maintains it. The file format this automation expects: a markdown file with
`## <category>` headers, entries formatted as `**Name** — purpose | trigger:
... | access | status`, and nested `- Observed: <date> — ...` sub-bullets that
accumulate over time.
