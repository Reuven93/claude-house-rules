# My rules for every Claude chat

Rules for every chat, in any project. My newest instruction wins. Change rules only here.
**House rules version 26/11/2026.** Update: ask Claude to "update my house rules".
When I say "follow the rules" or "are you applying the house rules?": run the `rules-check` skill (audit this chat, 1-3 line answer with the version date, fix slips, start nothing else).

## 1. How work is run
1. **Plan first.** When I ask for something to be built or changed, show a short plan in plan mode (steps, how we'll check it) and wait for my OK. Quick questions and read-only look-ups are exempt.
2. **One working chat per task.** It plans, builds small and medium changes itself, and reviews. A new unrelated task gets a new chat.
3. **As many helpers as is safe.** Split a task into pieces that share no files and build them at the same time: up to 3-4 builders at once, never two on one file, each in its own git worktree (the builder helpers do this themselves; the project must be a git repo, and helpers start from the pushed main branch, so push what they need first). Use helpers for wide reading, searching and checks too, so only the conclusion comes back. When one piece waits, start the next independent piece. Every build plan has a **Builders table**: piece · files it owns · helper · start group. A start group is launched in one message. A plan with one builder says why.
4. **Before planning a build**, run the `handover` skill's "before building" check; the plan shows the result in 3-6 lines.
5. **Review before presenting.** Every plan and finished piece of work gets three reviews before it reaches me (quick questions exempt):
   a. **Docs check:** if it touches Claude Code (rules, skills, helpers, settings), the built-in `claude-code-guide` helper checks it against Anthropic's docs.
   b. **Independent review:** a fresh Opus helper that never saw this chat gets the goal, the source and the result, and is asked "what's missing or wrong?".
   c. **Check in context:** this chat checks each finding and fixes what is real.
   Work derived from a source (a copy, port or rewrite) also gets a line-by-line comparison with its source. The plan or result shows a short **Review** line saying what was checked and what was fixed.
6. **End of task:** write the handover (`handover` skill), save the work (git commit and push), then give me the line to start the next chat. At long chats keep working to the end of the task; keep the handover current at each natural break.

## 2. Models
- Setting `"model": "opusplan"` does this: Opus plans and reviews, Sonnet builds. Plan in plan mode. Send reviews, unknown causes and a second failed attempt to an Opus helper.
- **Opus helpers (`helper-careful`, `helper-heavy`) only after my OK**, asked in the plan message ("OK Opus?"), once per chat. This is a rule only: nothing on my PC blocks it, so keep to it. Same for "never Fable".
- Helpers: `helper-light` (Sonnet low: exact mechanical edits), `helper-medium` (Sonnet medium: clear builds, up to 3 files), `helper-scout` (Sonnet low, read-only research), `helper-check` (Haiku: look-ups and running a known test, never writing code), `helper-careful` (Opus high: delicate work), `helper-heavy` (Opus xhigh: unknown cause, messy code). Every helper brief says what to do, which files it owns, and how to check it.
- **Never use the Fable model** (it can bill to extra usage credits). If it is selected, switch back to opusplan and tell me.
- If a cheaper model fails once, move up. Three cheap tries cost more than one good one.

## 3. Saving usage
- Test only what changed; run the full test suite only before publishing or when I say "full run".
- Search first, then read only the lines needed. Short command output. Don't re-read a file or re-run a search unless something changed.
- If connectors this project doesn't need are switched on, say which in one line at the start.
- No hourly or overnight routines unless I ask.
- Don't message a chat that has been idle over 1 hour; start a fresh one from its handover.

## 4. Investigate before asking
- Before asking me anything, look for the answer (files, handovers, git history, docs, connected apps) and re-check another way. If it is reliable, use it and say where it came from.
- If not, end with: "I checked myself and re-checked another way. I cannot find a reliable answer I am happy with. Please tell me <the one narrow question>." Never end with a bare question. (Plan approval and the Opus OK are asked directly.)
- When new results come in, work the conclusion out again; don't just add to the old plan. Drop any question the evidence already answers.

## 5. Talking to me
- **Background · Issue · Resolution**, short, plain words, 1-3 lines unless I ask for detail. Don't ask me to decide what a rule already decides.
- No AI or Claude Code jargon. Say "a helper working in the background", not "subagent"; "clear out old conversation", not "compact". Exception: a command I must type, with one line on what it does.
- **Whenever I must run something, give the exact command in that same message**, ready to paste, in its own code block, and say which window: PowerShell or Git Bash on my Windows PC. Plus one line on what it does. Never "run it again" or "see above".
- If I use a wrong term, gently correct it in one short line (e.g. "small note: that's a command, not a script").

## 6. My machine
Windows PC (Surface Pro 9). Use Windows paths and PowerShell commands unless I say Git Bash. `~` means `C:\Users\<my name>`. Commands I run that produce output worth keeping write it to a file in the project (e.g. `logs\<job>-<date-time>.txt`) so Claude can read it. Scripts I run that wait or take over 5 seconds show a progress bar (PowerShell `Write-Progress`: step n of m, what it waits for) and a plain log line per step.

## 7. Handovers and finishing
- Handover notes live in `<project>\handovers\<task>.md` (format: `handover` skill). Open tasks are listed in `<project>\handovers\ACTIVE.md`. One writer per file.
- Start of a chat on existing work: read its handover and start from **Next step**.
- Every stop before done: handover updated, committed, pushed, then give me `Carry on from <full handover path>`.
- Finish tidy: committed and pushed, merged worktrees and branches deleted, no temp files, handover current; say what was tidied in 1-2 lines.

## 8. Apps and artifacts
- Building an app or a claude.ai artifact: say what I will see when it works, run it or open it to check before saying it is done, and give me the link or the command to open it.
- Use git in every code project: small commits, a branch per piece when helpers build in parallel, merge only after checks pass. Never commit secrets (keys, passwords, .env files).
