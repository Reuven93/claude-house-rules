#!/bin/bash
# Role guard (strict roles): the front chat (Sonnet) only reports; helper-planner (Opus) plans; Sonnet builders build in the
# background; helper-reviewer (Opus) reviews. One script, event in $1 (PreToolUse|SubagentStop|Stop|SessionStart) or read from hook_event_name.
# Registered in settings by the owner of that file, not here. Bash only (Mac /bin/bash 3.2), no jq/python. Refuse = exit 2, reason on stderr.
#   SubagentStop            markers recorded here (works for background helpers too), from agent_type + last_assistant_message:
#                           helper-planner -> planner-<sid> (its reply); helper-reviewer -> reviewed-<sid>; helper-check -> checked-<sid>;
#                           any other type that is not read-only (helper-scout, Explore, claude-code-guide, web-fetch) -> built-<sid>.
#                           Counters hold a running number, so "newer" works within one second.
#   PreToolUse Agent|Task|Workflow|start_session  front chat starting a builder (any type except helper-planner/reviewer/scout/check, Explore,
#                           claude-code-guide, web-fetch; Workflow; start_session whose prompt has "ROLE: builder") needs one of:
#                           planner-<sid> + a newer plan-ok-<sid>; no-plan-<sid>; rules-update-<sid>; reviewed-<sid> newer than built-<sid>.
#   PreToolUse ExitPlanMode plan must equal planner-<sid> ignoring whitespace/markdown/case/punctuation (empty plan: newest plans file,
#                           only if newer than planner-<sid>).
#   PreToolUse Edit|Write|MultiEdit|NotebookEdit  refused for the front chat (no agent_id) and for helper-planner/reviewer/scout/check;
#                           exempt: ~/.claude/plans/ (front chat: plan mode only), memory notes, */handovers/*, ACTIVE.md (front chat).
#   PreToolUse Bash|PowerShell  front chat: allow-list only (command split at ; & && || | newline $( ` <( , quote-aware) plus a redirect
#                           check. helper-planner/reviewer/scout/check: write forms refused (redirect, sed -i, tee, dd, patch, git apply,
#                           bash -c, python -c, [IO.File]::, sc/ni/ri, cp, mv, rm, touch, mkdir, ln, git commit/merge/push/..., PowerShell
#                           Set-Content, Out-File, ...). Builders are not checked.
#   Stop                    once: built-<sid> newer than reviewed-<sid> -> exit 2 (stop_hook_active true = never twice). Small route: planner
#                           text contains "Size: small" and a helper-check run is newer than the last build -> passes.
#   SessionStart            model field (documented, "not always included") not Sonnet -> warning; absent -> log only.
# ROLE_GUARD_LOG_ONLY=1: a refusal is logged as "would refuse" and allowed; every event's sid, event and type is logged.
# role-off-<sid> in the state folder: refusals are allowed.
# Fields from the docs (code.claude.com/docs/en/hooks): agent_id/agent_type on hooks inside a subagent; SubagentStop agent_type +
# last_assistant_message; permission_mode; SessionStart model. Anything missing falls back to allow + a line in role-guard.log.
in=$(cat)
d=${CLAUDE_GUARD_STATE:-$HOME/.claude/guard-state}
field() { REPLY=; local r='(^|[^\\])"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] && REPLY=${BASH_REMATCH[2]}; }
log() { mkdir -p "$d" 2>/dev/null; printf '%s %s\n' "$(date +%FT%T)" "$1" >> "$d/role-guard.log" 2>/dev/null; }
refuse() {
  [ -f "$d/role-off-$sid" ] && exit 0
  if [ "$ROLE_GUARD_LOG_ONLY" = 1 ]; then log "would refuse (sid $sid $ev ${atype:-front} $tool): $1"; exit 0; fi
  echo "Blocked by the shared rules (role guard): $1" >&2; exit 2; }
unjson() { REPLY=$1; REPLY=${REPLY//\\n/$'\n'}; REPLY=${REPLY//\\t/ }; REPLY=${REPLY//\\r/ }; REPLY=${REPLY//\\\"/\"}; REPLY=${REPLY//\\\\/\\}; }
norm() { printf '%s' "$1" | LC_ALL=C sed -E 's/\\u[0-9a-fA-F]{4}//g' | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C tr -cd 'a-z0-9'; }
nextseq() { local n; n=$(cat "$d/seq" 2>/dev/null); n=$(( ${n:-0} + 1 )); echo "$n" > "$d/seq"; REPLY=$n; }
seqof() { REPLY=0; [ -f "$1" ] && { REPLY=$(cat "$1" 2>/dev/null); REPLY=${REPLY//[^0-9]/}; REPLY=${REPLY:-0}; }; }
field session_id; sid=${REPLY//[^A-Za-z0-9-]/}
ev=$1; if [ -z "$ev" ] || [ "$ev" = global ]; then field hook_event_name; ev=$REPLY; fi
field tool_name; tool=$REPLY
field agent_id; aid=$REPLY
field agent_type; atype=$REPLY
[ "$ROLE_GUARD_LOG_ONLY" = 1 ] && log "event sid=${sid:-none} ev=$ev type=${atype:-front} tool=${tool:--}"
[ -z "$sid" ] && { log "no session_id ($ev): allowed"; exit 0; }
shopt -s nocasematch extglob

RO='helper-@(planner|reviewer|scout|check)'                       # read-only helpers that may not write
NB='@(helper-planner|helper-reviewer|helper-scout|helper-check|Explore|claude-code-guide|web-fetch)'   # types that are not builders

builder_ok() {   # 0 = a builder may start
  [ -f "$d/no-plan-$sid" ] && return 0
  [ -f "$d/rules-update-$sid" ] && return 0
  [ -s "$d/planner-$sid" ] && [ -f "$d/plan-ok-$sid" ] && ! [ "$d/planner-$sid" -nt "$d/plan-ok-$sid" ] && return 0
  if [ -f "$d/reviewed-$sid" ]; then
    seqof "$d/built-$sid"; local b=$REPLY; seqof "$d/reviewed-$sid"; [ "$REPLY" -gt "$b" ] && return 0
  fi
  return 1
}

SEGS=()
split_cmd() {   # quote-aware split at ; & && | || newline $( ` <( into SEGS
  local s=$1 i n=${#1} ch nx cur= st= prev=
  SEGS=()
  for ((i=0;i<n;i++)); do
    ch=${s:i:1}; nx=${s:i+1:1}
    if [ "$st" = s ]; then cur+=$ch; [ "$ch" = "'" ] && st=; continue; fi
    if [ "$ch" = '\' ]; then cur+="$ch$nx"; i=$((i+1)); continue; fi
    if [ "$st" = d ]; then
      if [ "$ch" = '"' ]; then st=; cur+=$ch
      elif [ "$ch" = '$' ] && [ "$nx" = '(' ]; then SEGS+=("$cur"); cur=; i=$((i+1))
      elif [ "$ch" = '`' ]; then SEGS+=("$cur"); cur=
      else cur+=$ch; fi
      continue
    fi
    case "$ch" in
      "'") st=s; cur+=$ch ;;
      '"') st=d; cur+=$ch ;;
      ';'|'|'|$'\n'|'`') SEGS+=("$cur"); cur= ;;
      '&') if [ "$prev" = '>' ] || [ "$prev" = '<' ]; then cur+=$ch; else SEGS+=("$cur"); cur=; fi ;;
      '$'|'<') if [ "$nx" = '(' ]; then SEGS+=("$cur"); cur=; i=$((i+1)); else cur+=$ch; fi ;;
      *) cur+=$ch ;;
    esac
    prev=$ch
  done
  SEGS+=("$cur")
}

fwhy=
front_seg() {   # one segment; 0 = on the allow-list, else sets fwhy
  local s=$1 w rest sub ga t prev toks
  s=${s#"${s%%[![:space:]]*}"}; s=${s%"${s##*[![:space:]]}"}
  [ -z "$s" ] && return 0
  w=${s%%[[:space:]]*}; rest=${s#"$w"}; w=${w%%[\)\"\'\`]*}
  case "$w" in
    ls|cat|head|tail|wc|grep|stat|pwd|echo|printf|which|cd|diff|Get-*|Select-String|Test-Path) return 0 ;;
    rg) [[ $rest =~ (^|[[:space:]])--(pre|hostname-bin) ]] && { fwhy="rg --pre runs programs"; return 1; }; return 0 ;;
    find) [[ $rest =~ (^|[[:space:]])-(delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)([[:space:]]|$) ]] && { fwhy="find -delete/-exec/-fprint"; return 1; }; return 0 ;;
    sort) [[ $rest =~ (^|[[:space:]])(-[a-zA-Z]*o|--output) ]] && { fwhy="sort -o writes a file"; return 1; }; return 0 ;;
    date) [[ $rest =~ (^|[[:space:]])(-s|--set) ]] && { fwhy="date -s sets the clock"; return 1; }; return 0 ;;
    bash) [[ $s =~ ^bash[[:space:]]+[^[:space:]]*/tidy\.sh[[:space:]]+list([[:space:]]|\)|$) ]] && return 0
          fwhy="bash is only allowed as: bash <path>/tidy.sh list"; return 1 ;;
    git)
      if [[ $s =~ ^git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+([A-Za-z-]+)(.*)$ ]]; then sub=${BASH_REMATCH[2]}; ga=${BASH_REMATCH[3]}
      else fwhy="that git form"; return 1; fi
      [[ $ga == *--output* ]] && { fwhy="git --output writes a file"; return 1; }
      case "$sub" in
        status|log|diff|show|add|commit|fetch|rev-parse|ls-files|merge) return 0 ;;
        push) [[ $ga =~ (^|[[:space:]])(--force[a-z-]*|-f|-[a-zA-Z]*f[a-zA-Z]*|\+[^[:space:]]*|--delete|--mirror) ]] && { fwhy="git push --force"; return 1; }; return 0 ;;
        pull) [[ $ga =~ (^|[[:space:]])--ff-only([[:space:]]|$) ]] && return 0; fwhy="git pull needs --ff-only"; return 1 ;;
        worktree) [[ $ga =~ ^[[:space:]]+(list|remove|prune)([[:space:]]|$) ]] && return 0; fwhy="git worktree (only list, remove, prune)"; return 1 ;;
        config) [[ $ga =~ ^[[:space:]]+--get([[:space:]]|$) ]] && return 0; fwhy="git config (only --get)"; return 1 ;;
        branch)
          set -f; read -ra toks <<< "$ga"; set +f; shopt -u nocasematch
          case "${toks[0]}" in
            -d|--delete) for t in "${toks[@]}"; do case "$t" in -D|-f|--force|-m|-M|-c|-C) fwhy="git branch $t"; return 1;; esac; done; shopt -s nocasematch; return 0 ;;
          esac
          prev=
          for t in "${toks[@]}"; do
            case "$t" in
              -a|-r|-v|-vv|-l|--list|--all|--remotes|--verbose|--show-current|--merged|--no-merged|--contains|--no-contains|--sort=*|--format=*|--color|--no-color) ;;
              -*) fwhy="git branch $t"; return 1 ;;
              *) case "$prev" in --merged|--no-merged|--contains|--no-contains|-l|--list) ;; *) fwhy="git branch <name> creates a branch"; return 1 ;; esac ;;
            esac
            prev=$t
          done
          shopt -s nocasematch
          return 0 ;;
        *) fwhy="git $sub"; return 1 ;;
      esac ;;
  esac
  fwhy="not on the front chat's allow-list: $w"; return 1
}

case "$ev" in
SubagentStop)
  case "$atype" in
    helper-planner)
      field last_assistant_message; txt=$REPLY
      if [ -z "$txt" ]; then log "planner reply not found (sid $sid): not saved"; exit 0; fi
      mkdir -p "$d" 2>/dev/null; unjson "$txt"; printf '%s' "$REPLY" > "$d/planner-$sid" ;;
    helper-reviewer) mkdir -p "$d" 2>/dev/null; nextseq; echo "$REPLY" > "$d/reviewed-$sid" ;;
    helper-check) mkdir -p "$d" 2>/dev/null; nextseq; echo "$REPLY" > "$d/checked-$sid" ;;
    "") ;;
    $NB) ;;
    *) mkdir -p "$d" 2>/dev/null; nextseq; echo "$REPLY" > "$d/built-$sid" ;;
  esac
  exit 0 ;;

PreToolUse)
  case "$tool" in
  Agent|Task|Workflow|*start_session)
    [ -n "$aid" ] && exit 0
    bld=0
    case "$tool" in
      Workflow) bld=1 ;;
      *start_session) [[ $in == *"ROLE: builder"* ]] && bld=1 ;;
      *) field subagent_type; case "$REPLY" in $NB) ;; *) bld=1 ;; esac ;;
    esac
    if [ $bld = 1 ] && ! builder_ok; then
      refuse "no builder yet. Order: helper-planner plans, the user says OK, then Sonnet builders, then helper-reviewer."
    fi
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
    if [ -n "$aid" ]; then [[ $atype == $RO ]] || exit 0; fi
    field permission_mode; pm=$REPLY
    f=; r='"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] && f=${BASH_REMATCH[2]}
    f=${f//\\\\//}; f=${f//\\//}
    if [ -n "$aid" ]; then
      case "$f" in */.claude/plans/*) exit 0;; esac
      refuse "$atype only reads; it does not write files."
    fi
    case "$f" in
      */.claude/projects/*/memory/*) exit 0;;
      */handovers/*|*/ACTIVE.md|ACTIVE.md) exit 0;;
      */.claude/plans/*) [ "$pm" = plan ] && exit 0;;
    esac
    refuse "the front chat doesn't edit; give it to a Sonnet builder." ;;
  Bash|PowerShell)
    ro=0
    if [ -n "$aid" ]; then [[ $atype == $RO ]] && ro=1 || exit 0; fi
    field command; unjson "$REPLY"; c=$REPLY
    q=$(printf '%s' "$c" | perl -0pe 's/"[^"]*"|'"'"'[^'"'"']*'"'"'//gs' 2>/dev/null) || q=$c   # drop quoted text
    q=${q//2>&1/}; q=${q//>&2/}; q=$(printf '%s' "$q" | sed -E 's#[0-9&]?>>?[[:space:]]*/dev/null##g')
    why=
    [[ $q == *">"* ]] && why="a redirect to a file"
    if [ $ro = 1 ]; then
      b='(^|[;&|(`]|\$\(|xargs[[:space:]]+|-exec[[:space:]]+|sudo[[:space:]]+|then[[:space:]]+|do[[:space:]]+)[[:space:]]*'
      g='git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
      r="$b(sed[[:space:]]+(-[A-Za-z]*i|--in-place)|perl[[:space:]]+-[A-Za-z]*[ie]|tee|cp|mv|rm|touch|mkdir|ln|dd|patch|eval|truncate|rsync|install|(ba|z|da)?sh[[:space:]]+-[A-Za-z]*c|(python3?|node|ruby)[[:space:]]+-[ce]|${g}(commit|merge|push|reset|restore|stash|apply|am|clean|rm|mv|cherry-pick|rebase|pull)|${g}checkout[[:space:]]+(-b|--)|(Set-Content|Out-File|Add-Content|New-Item|Copy-Item|Move-Item|Remove-Item|sc|ni|ri))([[:space:]]|\$)"
      [ -z "$why" ] && [[ $q =~ $r ]] && why="a write command"
      [ -z "$why" ] && [[ $q =~ \[(System\.)?IO\.File\]:: ]] && why="[IO.File]::"
      [ -n "$why" ] && refuse "$atype only reads (found $why). Writing is for Sonnet builders."
      exit 0
    fi
    [ -n "$why" ] && refuse "the front chat only reads and reports (found $why). Give it to a Sonnet builder."
    split_cmd "$c"
    for seg in "${SEGS[@]}"; do
      front_seg "$seg" || refuse "the front chat may only run read-only commands, git save steps and tidy list ($fwhy). Give it to a Sonnet builder."
    done
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
