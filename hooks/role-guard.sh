#!/bin/bash
# Role guard (shared rules 26/11/2026i, strict roles): the front chat (Sonnet) only hands off and reports; helper-planner (Opus) plans; Sonnet builders
# build; helper-reviewer (Opus) reviews. One script, event in $1 (PreToolUse|SubagentStop|Stop|SessionStart) or read from hook_event_name.
# Registered in ~/.claude/settings.json (see the kit settings.json). Bash only, no jq/python. Refuse = exit 2, reason on stderr.
#   SubagentStop            markers are recorded here (works for background helpers too), from agent_type + last_assistant_message:
#                           helper-planner -> planner-<sid> (its reply); helper-reviewer -> reviewed-<sid>; helper-light/medium/builder ->
#                           built-<sid>; helper-check -> checked-<sid>. Counters hold a running number, so "newer" works within one second.
#                           PostToolUse is not used (a background start only returns "Async agent launched").
#   PreToolUse Agent        front chat starting helper-light/medium/builder with no planner-<sid> -> refused.
#   PreToolUse ExitPlanMode plan must equal planner-<sid> ignoring whitespace/markdown/case/punctuation (empty plan: newest plans file,
#                           only if newer than planner-<sid>).
#   PreToolUse Edit|Write|MultiEdit|NotebookEdit  refused for the front chat (no agent_id); exempt: ~/.claude/plans/ in plan mode,
#                           memory notes, */handovers/*, ACTIVE.md.
#   PreToolUse Bash|PowerShell  front chat, helper-planner, helper-reviewer: write forms refused (redirect, sed -i, tee, cp, mv, rm, touch,
#                           mkdir, ln, python -c, git merge|reset|restore|stash|checkout -b|checkout --, perl -i; PowerShell Set-Content,
#                           Out-File, Add-Content, New-Item, Copy-Item, Move-Item, Remove-Item). The front chat may git add/commit/push.
#   Stop                    once: built-<sid> newer than reviewed-<sid> -> exit 2 (stop_hook_active true = never twice). Small route: planner
#                           text contains "Size: small" and a helper-check run is newer than the last build -> passes.
#   SessionStart            model field (documented, "not always included") not Sonnet -> warning; absent -> log only.
# Fields from the docs (code.claude.com/docs/en/hooks): agent_id/agent_type on hooks inside a subagent; SubagentStop agent_type +
# last_assistant_message; permission_mode; SessionStart model. Anything missing falls back to allow + a line in role-guard.log.
in=$(cat)
d=${CLAUDE_GUARD_STATE:-$HOME/.claude/guard-state}
field() { REPLY=; local r='(^|[^\\])"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] && REPLY=${BASH_REMATCH[2]}; }
log() { mkdir -p "$d" 2>/dev/null; printf '%s %s\n' "$(date +%FT%T)" "$1" >> "$d/role-guard.log" 2>/dev/null; }
refuse() { echo "Blocked by the shared rules (role guard): $1" >&2; exit 2; }
unjson() { REPLY=$1; REPLY=${REPLY//\\n/$'\n'}; REPLY=${REPLY//\\t/ }; REPLY=${REPLY//\\r/ }; REPLY=${REPLY//\\\"/\"}; REPLY=${REPLY//\\\\/\\}; }
norm() { printf '%s' "$1" | LC_ALL=C sed -E 's/\\u[0-9a-fA-F]{4}//g' | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C tr -cd 'a-z0-9'; }
nextseq() { local n; n=$(cat "$d/seq" 2>/dev/null); n=$(( ${n:-0} + 1 )); echo "$n" > "$d/seq"; REPLY=$n; }
seqof() { REPLY=0; [ -f "$1" ] && { REPLY=$(cat "$1" 2>/dev/null); REPLY=${REPLY//[^0-9]/}; REPLY=${REPLY:-0}; }; }
field session_id; sid=${REPLY//[^A-Za-z0-9-]/}
ev=$1; if [ -z "$ev" ] || [ "$ev" = global ]; then field hook_event_name; ev=$REPLY; fi
[ -z "$sid" ] && { log "no session_id ($ev): allowed"; exit 0; }
field tool_name; tool=$REPLY
field agent_id; aid=$REPLY
field agent_type; atype=$REPLY
shopt -s nocasematch extglob

case "$ev" in
SubagentStop)
  case "$atype" in
    helper-planner)
      field last_assistant_message; txt=$REPLY
      if [ -z "$txt" ]; then log "planner reply not found (sid $sid): not saved"; exit 0; fi
      mkdir -p "$d" 2>/dev/null; unjson "$txt"; printf '%s' "$REPLY" > "$d/planner-$sid" ;;
    helper-reviewer) mkdir -p "$d" 2>/dev/null; nextseq; echo "$REPLY" > "$d/reviewed-$sid" ;;
    helper-light|helper-medium|helper-builder) mkdir -p "$d" 2>/dev/null; nextseq; echo "$REPLY" > "$d/built-$sid" ;;
    helper-check) mkdir -p "$d" 2>/dev/null; nextseq; echo "$REPLY" > "$d/checked-$sid" ;;
  esac
  exit 0 ;;

PreToolUse)
  case "$tool" in
  Agent|Task)
    [ -n "$aid" ] && exit 0
    field subagent_type
    case "$REPLY" in helper-light|helper-medium|helper-builder)
      [ -s "$d/planner-$sid" ] || refuse "Send the request to helper-planner first." ;; esac
    exit 0 ;;
  ExitPlanMode)
    [ -n "$aid" ] && exit 0
    field plan; p=$REPLY
    if [ -z "$p" ]; then
      pf=$(ls -t "$HOME"/.claude/plans/*.md 2>/dev/null | head -1)
      [ -z "$pf" ] && { log "no plan text (sid $sid): allowed"; exit 0; }
      if [ -f "$d/planner-$sid" ] && ! [ "$pf" -nt "$d/planner-$sid" ]; then log "plans file older than planner reply (sid $sid): allowed"; exit 0; fi
      p=$(cat "$pf")
    else unjson "$p"; p=$REPLY; fi
    [ -f "$d/planner-$sid" ] || refuse "Plans come from helper-planner word for word. Start helper-planner first."
    [ "$(norm "$p")" = "$(norm "$(cat "$d/planner-$sid")")" ] || refuse "Plans come from helper-planner word for word."
    exit 0 ;;
  Edit|Write|MultiEdit|NotebookEdit)
    [ -n "$aid" ] && exit 0
    field permission_mode; pm=$REPLY
    f=; r='"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] && f=${BASH_REMATCH[2]}
    f=${f//\\\\//}; f=${f//\\//}
    case "$f" in
      */.claude/projects/*/memory/*) exit 0;;
      */handovers/*|*/ACTIVE.md|ACTIVE.md) exit 0;;
      */.claude/plans/*) [ "$pm" = plan ] && exit 0;;
    esac
    refuse "the front chat doesn't edit; give it to a Sonnet builder." ;;
  Bash|PowerShell)
    if [ -n "$aid" ]; then [[ $atype == helper-@(planner|reviewer) ]] || exit 0; fi
    field command; unjson "$REPLY"; c=$REPLY
    q=$(printf '%s' "$c" | perl -0pe 's/"[^"]*"|'"'"'[^'"'"']*'"'"'//gs' 2>/dev/null) || q=$c   # drop quoted text
    q=${q//2>&1/}; q=${q//>&2/}; q=$(printf '%s' "$q" | sed -E 's#[0-9&]?>>?[[:space:]]*/dev/null##g')
    why=
    [[ $q == *">"* ]] && why="a redirect to a file"
    b='(^|[;&|(`]|\$\(|xargs[[:space:]]+|-exec[[:space:]]+|sudo[[:space:]]+|then[[:space:]]+|do[[:space:]]+)[[:space:]]*'
    g='git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
    gw='commit|merge|push|reset'; [ -z "$aid" ] && gw='merge|reset'      # the front chat may commit and push
    r="$b(sed[[:space:]]+(-[A-Za-z]*i|--in-place)|perl[[:space:]]+-[A-Za-z]*i|tee|cp|mv|rm|touch|mkdir|ln|python3?[[:space:]]+-c|${g}(${gw}|restore|stash)|${g}checkout[[:space:]]+(-b|--)|(Set-Content|Out-File|Add-Content|New-Item|Copy-Item|Move-Item|Remove-Item))([[:space:]]|\$)"
    [ -z "$why" ] && [[ $q =~ $r ]] && why="a write command"
    [ -n "$why" ] && refuse "this role only reads (found $why). The front chat, helper-planner and helper-reviewer don't write; give it to a Sonnet builder."
    exit 0 ;;
  esac
  exit 0 ;;

Stop)
  [ -n "$aid" ] && exit 0
  r='"stop_hook_active"[[:space:]]*:[[:space:]]*true'; [[ $in =~ $r ]] && exit 0
  [ -f "$d/built-$sid" ] || exit 0
  seqof "$d/built-$sid"; b=$REPLY; seqof "$d/reviewed-$sid"; v=$REPLY
  if [ "$b" -gt "$v" ]; then
    seqof "$d/checked-$sid"; k=$REPLY; r='Size:[[:space:]]*small'
    [ "$k" -gt "$b" ] && [ -f "$d/planner-$sid" ] && [[ $(cat "$d/planner-$sid") =~ $r ]] && exit 0
  fi
  [ "$b" -gt "$v" ] && refuse "A builder ran after the last review: start helper-reviewer before finishing."
  exit 0 ;;

SessionStart)
  field model; m=$REPLY
  [ -z "$m" ] && { log "SessionStart without model field (sid $sid): no check"; exit 0; }
  [[ $m == *sonnet* ]] && exit 0
  w="This chat runs on $m. The front chat must be Sonnet (Opus only inside helper-planner and helper-reviewer). Terminal: type /model sonnet. Desktop app: choose Sonnet in the model picker."
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$w" "$w"
  exit 0 ;;
esac
exit 0
