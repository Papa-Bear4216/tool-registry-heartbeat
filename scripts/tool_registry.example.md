---
name: tool-registry
description: "Inventory of tools/services you own, with trigger conditions + a growing log of observed real-world use cases for accurate proactive suggestion."
metadata:
  status: example
---

# Tool Registry

Format per entry:
**Name** — purpose | trigger: use when... | access | status
  - Observed: <date> — <what was actually happening when this tool was in use>

The "Observed" lines accumulate over time (via the heartbeat's discover pass and manual use). More observations = a sharper, evidence-based trigger instead of a single guess. Keep the `trigger:` line updated to reflect the *pattern* across observations, not just the first one.

## Dev / Infra

- **GitHub (your-org/your-repo)** — source repo | trigger: any code change, security review, branch compare | github.com, admin access | active
- **Vercel** — hosts your production deploy | trigger: any deploy/env-var/domain question | vercel.com | active
- **Supabase** — production backend | trigger: any data/auth work | supabase dashboard | active

## AI / Agents

- **Pieces MCP + Pieces OS** — background activity capture (browser, clipboard, screenshots, audio) + long-term memory/recall | trigger: "what was I doing when...", need historical context | Desktop app + PiecesOS running locally | active

## Newly Discovered (needs review)

(the heartbeat appends genuinely new tools/services here as they're observed — review and re-file periodically)

---
**How to apply**: When observing activity, cross-reference the `trigger:` line first. When a match fires (or nearly fires but doesn't meet the bar), append a dated Observed line under that entry — this is how triggers get sharper over time instead of staying a single guess. Update `trigger:` itself periodically to reflect the pattern across all Observed lines for that entry, not just the most recent one.
