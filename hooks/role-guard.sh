#!/bin/bash
# Role guard (shared rules 26/11/2026h, strict roles): the front chat (Sonnet) only hands off and reports; helper-planner (Opus) plans; Sonnet builders
# build; helper-reviewer (Opus) reviews. One script, event in $1 (PreToolUse|PostToolUse|Stop|SessionStart) or read from hook_event_name.
# Registered in ~/.claude/settings.json (see the kit settings.json). Bash only, no jq/python. Refuse = exit 2, reason on stderr.
#   PostToolUse Agent|Task  helper-planner -> planner-<sid> (its reply text); helper-reviewer -> reviewed-<sid>; builder -> built-<sid>
#                           (helper-light/medium/builder, or general-purpose on sonnet whose brief is not read-only). reviewed/built hold a
#                           running number, so "newer" works even within one second.
#   PreToolUse ExitPlanMode plan must equal planner-<sid> ignoring whitespace/markdown/case/punctuation.
#   PreToolUse Edit|Write|MultiEdit|NotebookEdit  refused for the front chat (no agent_id); exempt: ~/.claude/plans/ in plan mode, memory notes.
#   PreToolUse Bash         front chat, helper-planner, helper-reviewer: write forms refused (redirect to a file, sed -i, tee, cp, mv, rm,
#                           git commit|merge|push|reset|checkout -b, perl -i). Read-only commands pass.
#   Stop                    once: built-<sid> newer than reviewed-<sid> -> exit 2 (stop_hook_active true = never twice).
#   SessionStart            model field (documented, "not always included") not Sonnet -> warning; absent -> log only.
# Fields from the docs (code.claude.com/docs/en/hooks): agent_id/agent_type on hooks inside a subagent; permission_mode; PostToolUse
# tool_response.content = text blocks for Agent; SessionStart model. Anything missing falls back to allow + a line in role-guard.log.
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
PostToolUse)
  case "$tool" in Agent|Task) ;; *) exit 0;; esac
  [ -n "$aid" ] && exit 0                                        # nested helper: only the front chat's own calls count
  field subagent_type; t=$REPLY; field model; m=$REPLY
  mkdir -p "$d" 2>/dev/null
  case "$t" in
    helper-planner)
      rest=${in#*\"tool_response\"}; txt=
      re='"text"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
      while [[ $rest =~ $re ]]; do txt+=${BASH_REMATCH[1]}'\n'; rest=${rest#*"${BASH_REMATCH[0]}"}; done
      if [ -z "$txt" ]; then log "planner reply not found in tool_response (sid $sid): not saved"; exit 0; fi
      unjson "$txt"; printf '%s' "$REPLY" > "$d/planner-$sid" ;;
    helper-reviewer) nextseq; echo "$REPLY" > "$d/reviewed-$sid" ;;
    helper-light|helper-medium|helper-builder) nextseq; echo "$REPLY" > "$d/built-$sid" ;;
    general-purpose)
      [[ $m == *sonnet* ]] || exit 0
      field prompt; r='read[- ]only|do not (edit|write|modify|change)|no edits|research only'
      [[ $REPLY =~ $r ]] && exit 0
      nextseq; echo "$REPLY" > "$d/built-$sid" ;;
  esac
  exit 0 ;;

PreToolUse)
  case "$tool" in
  ExitPlanMode)
    [ -n "$aid" ] && exit 0
    field plan; p=$REPLY
    if [ -z "$p" ]; then
      pf=$(ls -t "$HOME"/.claude/plans/*.md 2>/dev/null | head -1)
      [ -z "$pf" ] && { log "no plan text (sid $sid): allowed"; exit 0; }
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
      */.claude/plans/*) [ "$pm" = plan ] && exit 0;;
    esac
    refuse "the front chat doesn't edit; give it to a Sonnet builder." ;;
  Bash)
    if [ -n "$aid" ]; then [[ $atype == helper-@(planner|reviewer) ]] || exit 0; fi
    field command; unjson "$REPLY"; c=$REPLY
    q=$(printf '%s' "$c" | perl -0pe 's/"[^"]*"|'"'"'[^'"'"']*'"'"'//gs' 2>/dev/null) || q=$c   # drop quoted text
    q=${q//2>&1/}; q=${q//>&2/}; q=$(printf '%s' "$q" | sed -E 's#[0-9&]?>>?[[:space:]]*/dev/null##g')
    why=
    [[ $q == *">"* ]] && why="a redirect to a file"
    b='(^|[;&|(`]|\$\(|xargs[[:space:]]+|-exec[[:space:]]+|sudo[[:space:]]+|then[[:space:]]+|do[[:space:]]+)[[:space:]]*'
    g='git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
    r="$b(sed[[:space:]]+(-[A-Za-z]*i|--in-place)|perl[[:space:]]+-[A-Za-z]*i|tee|cp|mv|rm|${g}(commit|merge|push|reset)|${g}checkout[[:space:]]+-b)([[:space:]]|\$)"
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
