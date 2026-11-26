#!/bin/bash
# PreToolUse (Agent | Task | start_session | set_session_model | set_session_effort): roles for models and effort (shared rules 2).
#   - Fable (model or helper type): always refused.
#   - Opus only for helper-planner and helper-reviewer (the user's OK is not needed for them). helper-careful / helper-heavy are retired.
#     Any other helper, side chat or session set to Opus is refused. A model named with a plan suffix is not treated as Opus (the front chat runs on Sonnet).
#   - Hard work runs on Sonnet builders (the planner diagnoses first). Session effort high/xhigh/max is refused, with no OK path: use low or medium.
#   - The built-in Plan helper is refused: plans come from helper-planner.
#   - helper-builder needs a "REPO: <path>" line at the start of its brief.
# Refuse = exit 2 with the reason on stderr (Claude sees it). Bash only, no jq/python (runs in Git Bash on Windows).
in=$(cat)  # $(</dev/stdin) reads nothing from the app's pipe on Windows; cat works on both
# A top-level JSON string field (not one quoted inside a prompt, where quotes are escaped as \")
field() { REPLY=; local r='(^|[^\\])"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]*)"'; [[ $in =~ $r ]] && REPLY=${BASH_REMATCH[2]}; }
refuse() { echo "Blocked by the shared rules (model guard): $1" >&2; exit 2; }
field tool_name; tool=$REPLY
shopt -s nocasematch extglob
isopus() { [[ $1 == *opus* && $1 != *opusplan* ]]; }
NOOPUS="Opus is only for helper-planner (plans) and helper-reviewer (reviews). Everything else runs on Sonnet or Haiku."
NOEFFORT="high effort costs tokens and there is no OK for it: use low or medium."
case "$tool" in
  Agent|Task)
    field model; m=$REPLY; field subagent_type; t=$REPLY
    { [[ $m == *fable* ]] || [[ $t == *fable* ]]; } && refuse "never use the Fable model. Use sonnet or haiku; Opus only through helper-planner and helper-reviewer."
    [[ $t == Plan ]] && refuse "the built-in Plan helper runs on the front chat's model; use helper-planner."
    if [[ $t == helper-@(careful|heavy) ]]; then refuse "helper-careful and helper-heavy are retired. $NOOPUS"; fi
    if isopus "$m" && [[ $t != helper-@(planner|reviewer) ]]; then refuse "$NOOPUS"; fi
    field effort; [[ $REPLY == @(high|xhigh|max) ]] && refuse "$NOEFFORT"
    if [[ $t == helper-builder ]]; then
      r='(\\n|"prompt"[[:space:]]*:[[:space:]]*")[[:space:]]*REPO:'
      [[ $in =~ $r ]] || refuse "helper-builder needs a REPO: line in the brief (the repo the builder works in)."
    fi ;;
  mcp__ccd_session__start_session)
    field proposal_id; [ -n "$REPLY" ] && exit 0   # an already-proposed card: checked when it was proposed
    field model; m=$REPLY
    [[ $m == *fable* ]] && refuse "never start a chat on the Fable model. Use a Sonnet model."
    isopus "$m" && refuse "$NOOPUS"
    field effort; [[ $REPLY == @(high|xhigh|max) ]] && refuse "$NOEFFORT" ;;
  mcp__ccd_session_mgmt__set_session_effort)
    field effort; [[ $REPLY == @(high|xhigh|max) ]] && refuse "$NOEFFORT" ;;
  mcp__ccd_session_mgmt__set_session_model)
    field model; [[ $REPLY == *fable* ]] && refuse "never move a chat to the Fable model."
    isopus "$REPLY" && refuse "$NOOPUS" ;;
esac
exit 0
