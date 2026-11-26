---
name: rules-check
description: "Use when I say \"follow the rules\", \"are you following the rules\", \"are you applying the shared rules\", \"are you applying the house rules\" or \"rules check\": audits this chat against my rules and fixes any slips."
---

# Rules check

Never keep a copy of the rules in this skill; always read the live ones.

1. Read the live rules: `~/.claude/shared-rules.md` and `~/.claude/CLAUDE.md` (on Windows `C:\Users\<name>\.claude\`; the second holds "My own rules", which win over the shared rules), plus the current project's `CLAUDE.md` if there is one.
2. Audit what this chat has done so far. Mark each pass, slip or not-applicable:
   - Front chat on Sonnet; it only handed work on and reported (no planning, building or reviewing itself).
   - Plan came from the planner helper, shown word for word, and OK'd before building.
   - Handover check done in the plan (the handover skill's "before building" step).
   - Builders table in the plan; independent pieces started in one message, up to 3-4, own worktree each.
   - Helper models fit the work; Opus only in the planner and reviewer helpers; Fable never used.
   - Plan and deliverable reviewed by the reviewer helper before shown, its review reported word for word with no added opinion (docs check if Claude Code; my own words given; derived work line-by-line)?
   - Tests only for what changed.
   - Handover current and saved at each break.
   - Replies short, plain, Background, Issue, Resolution; commands given paste-ready with the window named.
   - Rule changes got the Anthropic docs check.
3. Reply in 1-3 lines: the version line from the top of `shared-rules.md` and the version line (if any) in "My own rules" (e.g. "Shared rules version 26/11/2026c"), what slipped (if anything) and the fix being applied now. Name any "My own rules" entry or project rule that overrides a shared rule. Then apply the fixes and carry on. Do not start unrelated tidying.
