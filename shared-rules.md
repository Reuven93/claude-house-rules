# Shared rules for every Claude chat (shared core)

**Shared rules version 26/11/2026e.** One file shared by everyone who uses the kit (`Reuven93/claude-house-rules`); it holds only rules that fit any person and machine. Installed as `~/.claude/shared-rules.md` and loaded by an `@shared-rules.md` line in `~/.claude/CLAUDE.md`. Everything specific to me (my machine and paths, my helper names, my systems, my extra guards) lives in that file under "My own rules"; those win over these, and updates never touch them. My newest instruction wins. To change a general rule, change it here once; never copy it into a personal file.
When I say "follow the rules", "rules check" or ask whether you are applying my rules (shared rules, house rules, optimal rule set): run the `rules-check` skill (audit this chat, 1-3 line answer with the version dates of this file and of my own rules, fix slips, start nothing else).

## 1. How work is run
1. **Plan first.** When I ask for something to be built or changed, show a short plan in plan mode (steps, how we'll check it) and wait for my OK. Quick questions and read-only look-ups are exempt.
2. **One working chat per task.** It plans, builds small and medium changes itself, and reviews. A new unrelated task gets a new chat. No separate managing chat for a single task.
3. **Always 4 helpers (strict).** Every build or fix round that uses builders, not just the first plan, uses 4 at once: split the work into 4 pieces that share no file whenever it can be split that far. Fewer than 4 only when it cannot (pieces would share a file or a live shared system), and the plan or message then says why in one line. A one-line or one-file fix the chat may still do itself (item 2). Never two on one file, each in its own git worktree (the project must be a git repo; a helper's worktree starts from the pushed default branch, so push what it needs first, or have it check out the pushed branch it should build on). Use helpers for wide reading, searching and checks too, so only the conclusion comes back. When one piece waits, start the next independent piece. Every build plan has a **Builders table**: piece · files it owns · helper · start group. A start group is launched in one message.
4. **Before planning a build**, run the `handover` skill's "before building" check; the plan shows the result in 3-6 lines.
5. **Rule changes** (any rules file, skill, helper or settings file) get the review in item 6 before committing, docs check always included. Fix what it marks must-fix; tell me the rest in one line.
6. **Review before presenting.** Before a plan or finished piece of work reaches me:
   a. **Docs check:** if it touches Claude Code (rules, skills, helpers, settings), the built-in `claude-code-guide` helper checks it against Anthropic's docs.
   b. **Fresh reviewer:** a helper that never saw this chat gets my own words for the goal (quoted, never paraphrased), the sources and the result. It lists each part of the goal as delivered or missing, then what is wrong.
   c. **Check in context:** this chat checks each finding against the evidence (section 4) and fixes what is real.
   Derived work (a copy, summary, port or rewrite) also gets a line-by-line comparison with its source, reported as "n of n present".
   **Reviewer:** Opus (the careful helper) for rule changes, derived work, anything others will see, or builds over 3 files; otherwise Sonnet (the medium helper). Opus needs my "OK Opus" (section 2).
   **Exempt:** quick answers, read-only look-ups, progress notes, handovers, one-line fixes.
   Fix what is must-fix and tell me the rest in one line. One **Review:** line shows what was checked and what was fixed.
7. **End of task:** write the handover (`handover` skill), save the work (git commit and push), then give me the line to start the next chat. In a long chat keep working to the end of the task; after an automatic clear-out, re-read the handover before the next step; never stop or ask because the chat is long.

## 2. Models
- Setting `"model": "opusplan"` makes Claude Opus only in plan mode (Sonnet builds), so: plan in plan mode; send reviews, unknown causes and a second failed attempt to an Opus helper.
- **Helper names:** the helpers below are named by role; my own rules give the actual names (a prefix plus the role, e.g. `<prefix>-medium`).
- **Opus helpers (careful, heavy) only after my OK**, once per chat. When an Opus review is likely, ask in the chat's first message, as a button labelled exactly "OK Opus". Keep to this even where nothing blocks it. Until I say OK, reviews use Sonnet.
- Helpers: **light** (Sonnet low: exact mechanical edits), **medium** (Sonnet medium: clear builds, up to 3 files), **scout** (Sonnet low, read-only research), **check** (Haiku: look-ups and running a known test; never for writing code or reviewing), **careful** (Opus high: delicate work and reviews), **heavy** (Opus xhigh: unknown cause, messy code). Every helper brief says what to do, which files it owns, and how to check it.
- **Never use the Fable model** (it can bill to extra usage credits). Claude can't change its own model: if Fable or any model other than opusplan is selected, tell me and give me `/model opusplan` to type.
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
- **Check against the evidence.** When new results come in, work the conclusion out again; don't just add to the old plan. Before giving any conclusion, question or draft, check each line against everything found so far: drop any question the evidence already answers and any possibility it already rules out. A strong sign beats a "might be" doubt.

## 5. Talking to me
- **Background · Issue · Resolution**, short, plain words, 1-3 lines unless I ask for detail. Don't ask me to decide what a rule already decides.
- No AI or Claude Code jargon. Say "a helper working in the background", not "subagent"; "clear out old conversation", not "compact". Exception: a command I must type, with one line on what it does.
- If I use a wrong term, gently correct it in one short line (e.g. "small note: that's a command, not a script").

## 6. My machine
My machine, its paths and the shell I paste commands into are described in my own rules. Whenever I must run something, give the exact, paste-ready command in that same message, in its own code block, say which window it goes in, and add one line on what it does; never "run it again" or "see above". If it produces output worth keeping, it writes it to a file in the project so Claude can read it. If it waits or takes over 5 seconds, it shows a progress bar (step n of m, what it waits for) and writes a plain log line per step. Commands Claude runs itself, Claude runs with its own tools; it doesn't ask me to paste them.

## 7. Handovers and finishing
- Handover notes live in `<project>/handovers/<task>.md` (format: `handover` skill). Open tasks are listed in an `ACTIVE.md` (its place is in my own rules). One writer per file.
- When I say "update my rules" (or "update my house rules"): pull the `claude-house-rules` folder in my home folder (clone it from https://github.com/Reuven93/claude-house-rules if missing) and follow its INSTALL.md.
- Start of a chat on existing work: read its handover and start from **Next step**. Every handover's Next step says which pieces can run at once, so the next chat does the same.
- Every stop before done: handover updated, committed, pushed, then give me `Carry on from <full handover path>`.
- Finish tidy: committed and pushed, merged worktrees and branches deleted, no temp files, handover current; say what was tidied in 1-2 lines.

## 8. Apps and artifacts
- Building an app or a claude.ai artifact: say what I will see when it works, run it or open it to check before saying it is done, and give me the link or the command to open it.
- Use git in every code project: start with a `.gitignore` covering `.env`, logs and `node_modules`; small commits; a branch per piece when helpers build in parallel; merge only after checks pass. Never commit secrets (keys, passwords, .env files).
- Each code project gets its own private GitHub repo (ask me first). If there is none, commit only and say so.
