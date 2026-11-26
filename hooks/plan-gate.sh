#!/bin/bash
# Plan-first gate (shared rules, core 1.1/1.3/1.4/1.6). One script, three jobs:
#   PostToolUse ExitPlanMode  -> plan-ok-<session>: the plan was approved; lasts the chat.
#   PreToolUse  ExitPlanMode  -> the plan must carry what the rules ask for, or it is refused:
#       a build plan (mentions builders/build/implement/edit/create file): a Builders table (or "one builder"/"single builder" with
#       the reason), an open-tasks/handover-check result, and a "Review:" line. Any other plan: the "Review:" line only.
#   PreToolUse  Edit|Write|MultiEdit|NotebookEdit -> refused until plan-ok or no-plan exists for this chat (no-plan: prompt-gate.sh,
#       from "no plan"/"skip the plan"/"just do it"). Always allowed: helpers (agent_id), plan mode, handovers/, memory/, plans, scratch
#       and temp folders, ACTIVE.md, notes under .claude/projects/, chats started "Carry on from", unreadable transcript.
# Bash is never gated. Refuse = exit 2, reason on stderr. Bash only, no jq/python (runs in Git Bash on Windows).
in=$(cat)
field() { REPLY=; local r='(^|[^\\])"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] && REPLY=${BASH_REMATCH[2]}; }
refuse() { echo "Blocked by the shared rules (plan gate): $1" >&2; exit 2; }
field session_id; sid=${REPLY//[^A-Za-z0-9-]/}
[ -z "$sid" ] && exit 0
d=${CLAUDE_GUARD_STATE:-$HOME/.claude/guard-state}
field hook_event_name; ev=$REPLY
field tool_name; tool=$REPLY
shopt -s nocasematch

if [ "$tool" = ExitPlanMode ]; then
  if [ "$ev" = PostToolUse ]; then mkdir -p "$d" 2>/dev/null; : > "$d/plan-ok-$sid"; exit 0; fi
  field plan; p=$REPLY
  miss=
  [[ $p == *"review:"* ]] || miss="$miss"$'\n'"- a \"Review:\" line (what will be checked, by which reviewer)"
  if [[ $p == *builders* || $p == *build* || $p == *implement* || $p == *"edit "* || $p == *"create file"* ]]; then
    { [[ $p == *builders* && $p == *"|"* ]] || [[ $p == *"one builder"* || $p == *"single builder"* ]]; } ||
      miss="$miss"$'\n'"- a Builders table (piece | files it owns | helper | start group), or a line saying why there is one builder"
    [[ $p == *handover* || $p == *open-tasks* || $p == *"open tasks"* || $p == *"before building"* ]] ||
      miss="$miss"$'\n'"- the result of the handover \"before building\" check (open tasks, owners, contradictions)"
  fi
  [ -n "$miss" ] && refuse "the plan is missing:$miss"
  exit 0
fi

case "$tool" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0;; esac
{ [ -f "$d/plan-ok-$sid" ] || [ -f "$d/no-plan-$sid" ]; } && exit 0
field agent_id; [ -n "$REPLY" ] && exit 0                       # helper
field permission_mode; [ "$REPLY" = plan ] && exit 0             # plan mode: plan file writes
f=; r='"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] && f=${BASH_REMATCH[2]}
f=${f//\\\\//}; f=${f//\\//}                                      # JSON-escaped or plain backslashes -> /
case "$f" in
  */handovers/*|*/memory/*|*/.claude/plans/*|*scratchpad*|/tmp/*|/private/tmp/*|*/AppData/Local/Temp/*|ACTIVE.md|*/ACTIVE.md|*/.claude/projects/*.md) exit 0;;
esac
# chat started as a continuation: the first user message in the transcript
field transcript_path; t=${REPLY//\\\\//}; t=${t//\\//}
{ [ -n "$t" ] && [ -r "$t" ]; } || exit 0                        # no transcript to read: allow
first=$(grep -m3 '"type"[[:space:]]*:[[:space:]]*"user"' "$t" 2>/dev/null | head -c 6000)
r='"content"[[:space:]]*:[[:space:]]*(\[[^]]*"text"[[:space:]]*:[[:space:]]*)?"[[:space:]]*(Carry on from)'
[[ $first =~ $r ]] && exit 0
refuse "Plan first: show a plan in plan mode and get the OK (or the user says 'no plan')."
