#!/bin/bash
# PreToolUse (Agent | Task | Workflow | start_session | set_session_model | set_session_effort): every helper gets a deliberately
# chosen model and level, never Fable, and Opus only for helper-planner / helper-reviewer (shared rules).
#   - Fable: always refused.
#   - Opus: only helper-planner / helper-reviewer (with a TIER 3-4 line, no OK needed); everything else is refused.
#     A session on "opusplan" is NOT Opus (it uses Opus only while planning).
#   - Agent/Task: a model (helper-* type or model param) is required, except the utility types. A TIER line is required only
#     for Opus / high effort (must be 3-4). Sonnet/Haiku is allowed at every TIER (all building runs on Sonnet; the planner diagnoses first). TIERs: 0 look-ups, 1 research/simple edits, 2 clear builds up to 3 files, no money,
#     3 money/rates/billing/credit notes/totals, 4 unknown cause/wrong numbers/messy code.
# Refuse = exit 2 with the reason on stderr (Claude sees it). Reminder = JSON additionalContext. No jq; bash only.
# Registered in ~/.claude/settings.json (see settings.json in the kit).
in=$(cat)  # $(</dev/stdin) reads nothing from the app's pipe on Windows (found 13/11); cat works on both
tool=; re='"tool_name"[[:space:]]*:[[:space:]]*"([^"]+)"'; [[ $in =~ $re ]] && tool=${BASH_REMATCH[1]}
# A top-level JSON string field of tool_input (not one quoted inside a prompt, where quotes are escaped as \")
field() { REPLY=; local r='(^|[^\\])"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]*)"'; [[ $in =~ $r ]] && REPLY=${BASH_REMATCH[2]}; }
refuse() { echo "Blocked by the shared rules (model guard): $1" >&2; exit 2; }
remind() { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$1"; exit 0; }
field session_id; sid=${REPLY//[^A-Za-z0-9-]/}
shopt -s nocasematch extglob
# One log line per tool name, to learn which session-model tool name the app really fires: <guard-state>/model-guard.log
case "$tool" in *set_session_model|*set_session_effort)
  gd=${CLAUDE_GUARD_STATE:-$HOME/.claude/guard-state}; mkdir -p "$gd" 2>/dev/null
  grep -qs -F " tool=$tool" "$gd/model-guard.log" || printf '%s session-model tool fired: tool=%s\n' "$(date +%FT%T)" "$tool" >> "$gd/model-guard.log" 2>/dev/null ;;
esac
isopus() { [[ $1 == *opus* && $1 != *opusplan* ]]; }  # opusplan = Opus only while planning, so not Opus here
NOOPUS="Opus is only for helper-planner and helper-reviewer (strict roles). Everything else runs on Sonnet or Haiku."
NEEDTIER="Opus, planner/reviewer or high effort needs a TIER 3 or 4 line in the brief. For smaller work use Sonnet; otherwise raise the TIER."
# Opus (model or helper-careful/heavy) or effort high/xhigh/max asked for: the brief's TIER line must be 3 or 4. $1=model $2=type $3=effort
tier_ok() {
  isopus "$1" || [[ $2 == helper-@(careful|heavy|planner|reviewer) || $3 == @(high|xhigh|max) ]] || return 0
  local r='(\\n|"prompt"[[:space:]]*:[[:space:]]*")[[:space:]]*TIER:[[:space:]]*([0-4])'
  [[ $in =~ $r ]] && [[ ${BASH_REMATCH[2]} == [34] ]]
}
case "$tool" in
  Agent|Task)
    field model; m=$REPLY; field subagent_type; t=$REPLY
    [[ $m == *fable* ]] && refuse "never use Fable for a helper. Use sonnet (research, checks), haiku (simple lookups, kit runs)."
    [[ $t == *fable* ]] && refuse "the helper-fable worker is off: Fable is never used on agents. Use helper-scout (Sonnet) or helper-check (Haiku)."
    [[ $t == Plan ]] && refuse "the built-in Plan helper runs on the front chat's model; use helper-planner."
    # Roles: Opus only for helper-planner / helper-reviewer (no OK needed, but a TIER 3-4 line); careful/heavy and any other Opus are refused.
    if [[ $t == helper-@(careful|heavy) ]] || { isopus "$m" && [[ $t != helper-@(planner|reviewer) ]]; }; then refuse "$NOOPUS"; fi
    field effort; tier_ok "$m" "$t" "$REPLY" || refuse "$NEEDTIER"
    case "$t" in Explore|Plan|claude-code-guide|web-fetch|statusline-setup) exit 0;; esac  # utility helpers: fixed or cheap model
    [[ $t == helper-* ]] || refuse "use a helper-* type (helper-scout, helper-check, helper-medium, helper-builder, helper-planner, helper-reviewer). General-purpose and untyped helpers are refused."
    if [[ $t == helper-builder ]]; then
      r='(\\n|"prompt"[[:space:]]*:[[:space:]]*")[[:space:]]*REPO:'
      [[ $in =~ $r ]] || refuse "helper-builder needs a REPO: line in the brief (the repo the builder works in)."
    fi
    r='(\\n|"prompt"[[:space:]]*:[[:space:]]*")[[:space:]]*TIER:[[:space:]]*([0-4])'
    [[ $in =~ $r ]] || exit 0   # no TIER line: fine for Sonnet/Haiku (Opus/high effort already needed one above)
    exit 0 ;;   # TIER 4 on Sonnet/Haiku is fine: the planner diagnoses first
  Workflow)
    # The script is a JSON string, so its quotes arrive escaped; look for any agent set to Fable or the helper-fable worker.
    r='model[\\"'"'"']*[[:space:]]*:[[:space:]]*[\\"'"'"']*fable'
    [[ $in =~ $r || $in == *helper-fable* ]] && refuse "a workflow agent is set to Fable. Use sonnet or haiku for workers."
    r='model[\\"'"'"']*[[:space:]]*:[[:space:]]*[\\"'"'"']*[A-Za-z0-9._-]*opus([^p]|$)'
    if [[ $in =~ $r || $in == *helper-@(careful|heavy)* ]]; then refuse "$NOOPUS"; fi
    r='model[\\"'"'"']*[[:space:]]*:[[:space:]]*[\\"'"'"']*(sonnet|haiku)'
    [[ $in =~ $r ]] || remind "Model guard: no workflow agent here is set to sonnet or haiku. Give research, review and check agents model sonnet or haiku." ;;
  mcp__ccd_session__start_session)
    field proposal_id; [ -n "$REPLY" ] && exit 0   # starting an already-proposed card: its model was checked then
    field model; m=$REPLY; field context; c=$REPLY; field initiation; i=$REPLY
    [[ $m == *fable* ]] && refuse "never start a side chat on Fable. Use a Sonnet model id by default, Haiku for checks."
    isopus "$m" && refuse "$NOOPUS"
    field effort; tier_ok "$m" "" "$REPLY" || refuse "$NEEDTIER"
    [ "$i" = offer ] && exit 0                       # an offer card carries only a title; the model comes with the brief
    if [ -z "$m" ]; then
      [ "$c" = fork ] && refuse "a forked chat runs on this chat's model: state the model (model claude-sonnet-5-5 by default, claude-haiku-5-5 for checks)."
      refuse "choose the side chat's model explicitly: model claude-sonnet-5-5 by default, claude-haiku-5-5 for checks or kit runs. Set effort too (low or medium unless the work needs more)."
    fi
    r='(\\n|"prompt"[[:space:]]*:[[:space:]]*")[[:space:]]*ROLE:[[:space:]]*builder'
    if [[ $in =~ $r ]]; then                         # a builder chat: it may edit code, so it needs a level like any helper
      exit 0   # TIER 4 on Sonnet is allowed
    fi ;;
  mcp__ccd_session_mgmt__set_session_model)
    field model; [[ $REPLY == *fable* ]] && refuse "never move a chat to Fable."
    isopus "$REPLY" && refuse "$NOOPUS" ;;
  mcp__ccd_session_mgmt__set_session_effort)
    field effort; [[ $REPLY == @(high|xhigh|max) ]] && refuse "high effort costs tokens and there is no OK for it: use low or medium." ;;
esac
exit 0
