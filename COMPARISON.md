# Comparison: Reuven's rules vs the starter kit

Every rule in `admin/claude-user-CLAUDE.md` (R) and the workspace `Projects/CLAUDE.md` (W), plus the new "Review before presenting" rule, with what the kit does. Kit section numbers refer to `CLAUDE.md` in this repo.

| # | Source rule | Verdict | Kit / reason |
|---|---|---|---|
| R0a | Header: source copy path, cloud chats get it from start-up check | drop | Mac/repo-specific; replaced by a version line and "update my house rules" pointer |
| R0b | Newest instruction wins; change rules only here; procedures in skills; settings enforce | adapt | Kept as one header line (newest wins, change rules only here); the "settings enforce" part dropped (needs his hooks) |
| R0c | Version line + "are you applying the optimal rule set?" runs rules-check | adapt | "House rules version 26/11/2026"; trigger phrases renamed to "house rules"; rules-check skill kept |
| R1.1 | One working chat per task | keep | 1.2 |
| R1.2a | As many helpers as safe: 3-4 builders, no two on one file, own worktree | keep | 1.3 |
| R1.2b | Only one at a time on a shared system (BI server, Parcel Perfect, Outlook) | drop | Business systems. Not generalised: she has none yet |
| R1.2c | Helpers for wide reading/searching, tests, checks | keep | 1.3 |
| R1.2d | When one piece waits, start the next independent piece | keep | 1.3 |
| R1.2e | Builders table (piece, files, helper, start group); start group in one message; one builder says why | keep | 1.3 |
| R1.2f | Handover Next step says which pieces can run at once | adapt | Dropped from rules; the handover template's Next step covers it ("one concrete action"). Add back if she wants it |
| R1.2g | `isolation: worktree` starts from main, so push what it needs first | adapt | Builders have `isolation: worktree` (agents/*). The "push first" tip dropped from rules (detail for his setup); noted here as a tip |
| R1.3 | Separate chats only for hours/days-long work; check ACTIVE.md, one owner per topic | adapt | 1.2 says new unrelated task = new chat; ACTIVE.md became a simple generic `handovers\ACTIVE.md` (7). "Separate steering chats" dropped: advanced |
| R1.4a | End of task: write handover, hand off yourself | adapt | 1.6: write handover, save, give me the start line. Auto hand-off dropped (see R7.5) |
| R1.4b | 150k warning: keep working, never stop because of size | adapt | 1.6 "keep working to the end of the task". Numbers dropped: they come from his settings/hooks |
| R1.4c | Handover current at each break; re-read after automatic clear-out | keep | 1.6 and 7 (re-read after clear-out folded into "start of a chat: read the handover") |
| R1.5a | Rule changes: Anthropic docs check by `claude-code-guide` before committing | keep | 1.5a (now part of Review before presenting) |
| R1.5b | Docs check is on top of any Opus review; fix must-fix, tell the rest in one line | keep | 1.5 (three reviews, findings checked in context) |
| R2.1 | Opus plans/reviews, Sonnet builds; `opusplan`; plan in plan mode; Opus for reviews, unknown causes, second failure | keep | 2 and settings.json |
| R2.2 | Reuven's OK once per chat for Opus; plan message asks "OK Opus"; model guard enforces | adapt | 2: Opus helpers only after her OK in the plan message. The guard hook is not ported, so this is a rule only |
| R2.3 | Money builds: pass/fail check against known-right figures; fresh Opus review | adapt | Business-only wording dropped. Generalised: Review before presenting (1.5b, fresh Opus reviewer) and "how to check it" in every plan/brief |
| R2.4 | Every helper brief starts with `TIER: n` (0-4); Opus needs TIER 3-4; guard enforces | drop | Depends on a Mac hook. Replaced by "Opus helpers only after OK" and model-by-task list in 2 |
| R2.5 | Sonnet for clear builds/research/edits (savvy-light/medium/scout) | keep | 2 (helper-light/medium/scout) |
| R2.6 | Haiku for look-ups, running a known test; never writing code or reviewing | keep | 2 (helper-check) |
| R2.7 | Never Fable (can bill extra usage credits) | keep | 2. Stopping it with settings: **to verify** (see below) |
| R2.8 | Move up a model after one failed attempt | keep | 2 |
| R3.1 | Test only what changed (console `run-all.sh --changed`, `--full` only before publishing) | adapt | 3: test only what changed, full run before publishing or when she says "full run". Console script and code guard dropped |
| R3.2 | Search then read only needed lines; short output; don't re-read | keep | 3 |
| R3.3 | Say which unlisted connectors are on; no hourly/overnight routines | adapt | 3 (generic: connectors this project doesn't need). Project-CLAUDE.md-list wording dropped |
| R3.4 | Never message a chat idle over 1 hour | keep | 3 |
| R4.1 | Investigate before asking; list of Sunrise systems | adapt | 4 with generic sources (files, handovers, git, docs, connected apps) |
| R4.2 | "I checked myself and re-checked another way..." wording, never a bare question; plan approval and Opus OK exempt | keep | 4 ("Please tell me" replaces "contact <who>") |
| R4.3 | Check against the evidence; drop answered questions | keep | 4 |
| R5.1 | Background, Issue, Resolution; 1-3 lines | keep | 5 |
| R5.2 | No AI jargon | keep | 5 |
| R5.3 | Exact paste-ready command, window named (PowerShell on the server / Terminal on the Mac), one line what it does | adapt | 5: window = PowerShell or Git Bash on Windows |
| R5.4 | Gently correct wrong terms | keep | 5 |
| R6.1 | Mac only, never Windows steps | adapt | Reversed: 6 says Windows PC (Surface Pro 9) |
| R6.2 | bi-server-deploy folder, Remote Desktop share | drop | Business server setup |
| R6.3 | Server commands log to `\\tsclient\...\logs`, Claude reads on the Mac | adapt | 6: output worth keeping goes to `logs\` in the project |
| R6.4 | PowerShell scripts show `Write-Progress`, plain log line per step | keep | 6 |
| R7.1 | Handovers in `<project>/handovers/<task>.md`; code repos per their CLAUDE.md; ACTIVE.md; one writer | adapt | 7 with Windows paths; generic `handovers\ACTIVE.md` |
| R7.2 | Start of chat on existing work: read handover, start from Next step | keep | 7 |
| R7.3 | Before planning a build: handover check by a background helper | keep | 1.4 and handover skill |
| R7.4 | Every stop before done: handover, commit, push, `Carry on from <path>` | keep | 7 |
| R7.5 | Handing off: start next chat yourself, move to top level, archive chats, git status clean | drop | Depends on Claude desktop app session tools on his Mac (start/archive sessions); she gets the `Carry on from` line instead |
| R7.6 | Finish tidy | keep | 7 and handover skill |
| W-org | One folder per project with own CLAUDE.md and handovers/; ACTIVE.md; new projects from `_template/` | adapt | Per-project `handovers\` + `ACTIVE.md` kept (7). Workspace layout, `_template/` dropped (his repo) |
| W-io | `inputs/` and `outputs/` gitignored, business data stays off GitHub | drop | Business data policy. Kept only the general "never commit secrets" in 8 |
| W-repos | Table of his code repos | drop | Business-only |
| W0 | Plan first, plan mode, "OK Opus" in same message | keep | 1.1 and 2 |
| W1 | Cloud or Mac? Say which in one line | drop | Mac vs cloud split with his connectors; she works on one Windows PC |
| W2 | Right folder: task chats start in the project folder | adapt | Not a rule in the kit (no start-up warning hook). Mentioned in README as a tip |
| W3 | Handovers per project, one line per task in ACTIVE.md | keep | 7 |
| W4 | Files in `outputs/` as `YYYY-MM-DD`; Downloads to `inputs/`; never move Credit Note Reports | drop | His folder conventions and live pipeline |
| W5 | New unrelated task: new chat | keep | 1.2 |
| W6 | Git: shared memory, commit and push handovers, never commit business data, short CLAUDE.md | adapt | 1.6, 7, 8 (git for code, secrets never committed); "keep CLAUDE.md short" kept in spirit by length |
| NEW | Review before presenting (docs check, independent Opus review, check in context, line-by-line comparison for derived work, Review line) | keep | 1.5; also in rules-check |
| Skill | handover skill: Sunrise paths, ACTIVE.md in ~/Projects, session-status file, Reuven's standing hand-off | adapt | Generic `skills/handover/SKILL.md` + `TEMPLATE.md`; session-status line and auto hand-off dropped |
| Skill | rules-check skill: reads live rules, audits, 1-3 line reply | adapt | Generic; reads `~/.claude/CLAUDE.md`; Mac/cloud, folder, TIER items removed, review item added |
| Agents | 6 savvy-* helpers | adapt | Renamed `helper-*`; same models, effort, worktree on 4 builders; TIER/Reuven's OK text replaced by "after my OK" |
| Settings | `model: opusplan` | keep | settings.json |
| Settings | `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` 6, `..._SPAWN_DEPTH` 1 | keep | settings.json |
| Settings | `CLAUDE_CODE_SUBAGENT_MODEL: sonnet`, autocompact 18, context soft/hard, notification flags | drop | His tuning (clear-out point, size warnings); not needed to start. Could be added later |
| Settings | Hooks (rules-check.sh, prompt-gate, master-guard, model-guard, code-guard...) | drop | Mac bash scripts; depend on his paths |
| NEW (not in his) | Section 8 Apps and artifacts | add | Her main use: check before "done", give link or command, git habits, no secrets |

## Counts
Rows: 65 in total (rules, skills, agents, settings and the new rule). Keep 31, adapt 22, drop 11, add 1.

## To verify (not invented)
- **Blocking Fable by setting:** Claude Code has an `availableModels` setting (documented for managed/enterprise settings) that limits which models can be selected. We believe it can restrict the `/model` picker, but we have not verified it for personal settings or for a Windows PC without an admin policy, and have not added it. Until checked, the rule in `CLAUDE.md` section 2 is the only protection.
- `isolation: worktree` in agent files and `effort:` in agent files: copied from Reuven's working helpers, so known to load there.
