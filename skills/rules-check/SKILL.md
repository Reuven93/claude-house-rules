---
name: rules-check
description: "Use when I say \"follow the rules\", \"are you following the rules\", \"are you applying the house rules\" or \"rules check\": audits this chat against my rules and fixes any slips."
---

# Rules check

Never keep a copy of the rules in this skill; always read the live ones.

1. Read the live rules: `~/.claude/CLAUDE.md` (on Windows `C:\Users\<name>\.claude\CLAUDE.md`) and the current project's `CLAUDE.md` if there is one.
2. Audit what this chat has done so far. Mark each pass, slip or not-applicable:
   - Plan shown and OK'd before building.
   - Handover check done in the plan (the handover skill's "before building" step).
   - Builders table in the plan; independent pieces started in one message, up to 3-4, own worktree each.
   - Helper models fit the work; Opus helpers only after my OK; Fable never used.
   - Review before presenting: docs check (if Claude Code was touched), independent Opus review, findings checked in context, line-by-line comparison for derived work, "Review" line shown.
   - Tests only for what changed.
   - Handover current and saved at each break.
   - Replies short, plain, Background, Issue, Resolution; commands given paste-ready with the window named.
   - Rule changes got the Anthropic docs check.
3. Reply in 1-3 lines: the rules version date (from the `CLAUDE.md` header), what slipped (if anything) and the fix being applied now. Name any project rule that overrides a house rule. Then apply the fixes and carry on. Do not start unrelated tidying.
