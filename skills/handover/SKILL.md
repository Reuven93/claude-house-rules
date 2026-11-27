---
name: handover
description: "Use when writing or updating a handover, finishing or stopping a task, or before planning or starting any build (handover check): handover format, finish-tidy steps, overlap check."
---

# Handover and finish

A handover is a short note so a fresh chat can carry on a task. Where: `<project>\handovers\<task>.md`. Format: `TEMPLATE.md` next to this skill (copy it). One writer per file.

`<project>\handovers\ACTIVE.md` is a simple list, one line per open task: `<task> - <status> - <path to its handover>`. Add a line when a task starts, remove it when the task is done. Create the file if missing.

Known failures (standing rule, Reuven 27/11: "so mistakes are not repeated"): every handover has a "Known failures (read before any retry)" section. Read it first, before any plan, build, review or retry. Add a line for every failed or stopped run before the next attempt (format in the template: date time, what was run, log file, failing check quoted, cause, fix/owner, status OPEN|FIXED). Keep FIXED lines. Planner, builder and reviewer briefs say "read Known failures first".

## No duplicated work
- After an automatic clear-out of old conversation, re-read the handover before the next step.
- Starting from a handover: trust "Already done". Re-run a check only if the code it covered has changed (`git diff <recorded commit>`); re-check a fact only if its source can change and the task depends on today's value.
- Helper briefs: paste the verified facts and say "already verified, do not re-check"; ask only for what is new.

## Before building: check other handovers
- When: in the plan step of any build, before the plan is shown (so the plan includes the result). Also when starting a chat on existing work.
- How: start one read-only helper in the background (`helper-scout`). It reads `handovers\ACTIVE.md` and the relevant handovers and returns only a short table: handover path · owner chat · status · files it touches that overlap this task · work already done, or conflicts with this task or with each other. It cites file and line for each claim and marks anything it could not verify. This chat then reads only the handovers it will act on.
- First read the Known failures section of each relevant handover; the plan lists any OPEN failure and how it is avoided.
- Work already done: don't redo it; say so in the plan. Owned by another live chat: don't build it here; say who owns it. Handovers that contradict each other: list the contradiction in the plan and say which is newer or backed by evidence.
- The plan shows this as a 3-6 line "Handover check" section. If there is no `handovers` folder yet, say "no earlier handovers" and move on.

## Steps when finishing or stopping
1. Update the handover (Status, Last updated, Next step). Add a Known failures line for every failed or stopped run (keep FIXED lines).
2. Update `handovers\ACTIVE.md` (remove the line if the task is done).
3. Commit the changed files by explicit path and push (if the project uses git).
4. If not done, end with `Carry on from <full handover path>` for me to paste into a new chat.

## Finish tidy
Committed and pushed, merged worktrees and branches deleted, no temp files, handover and ACTIVE.md current. Tell me what was tidied in 1-2 lines.
