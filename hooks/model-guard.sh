#!/bin/bash
# PreToolUse (Agent | Task | mcp__ccd_session__start_session): never the Fable model; the stronger model (Opus) only with the user's OK.
#   - Fable (model or helper type): always refused.
#   - Opus (helper-careful / helper-heavy, model opus, a session started on opus): needs the marker that prompt-gate.sh writes only
#     when the user's own prompt approves it ("ok opus", "yes use opus", ...). helper-light/medium/scout/check need no OK.
#     "opusplan" is not Opus (it uses Opus only while planning).
# Refuse = exit 2 with the reason on stderr (Claude sees it). Bash only, no jq/python (runs in Git Bash on Windows).
in=$(cat)  # $(</dev/stdin) reads nothing from the app's pipe on Windows; cat works on both
# A top-level JSON string field (not one quoted inside a prompt, where quotes are escaped as \")
field() { REPLY=; local r='(^|[^\\])"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]*)"'; [[ $in =~ $r ]] && REPLY=${BASH_REMATCH[2]}; }
refuse() { echo "Blocked by the shared rules (model guard): $1" >&2; exit 2; }
field tool_name; tool=$REPLY
field session_id; sid=${REPLY//[^A-Za-z0-9-]/}
approved() { [ -n "$sid" ] && [ -f "${CLAUDE_GUARD_STATE:-$HOME/.claude/guard-state}/opus-ok-$sid" ]; }
NEEDOK="This needs the user's OK for the stronger model. Ask in one line (what needs it and why) with a reply button labelled \"OK Opus\"; one OK lasts the rest of this chat. Don't start it yourself and don't drop to the cheaper model."
shopt -s nocasematch
isopus() { [[ $1 == *opus* && $1 != *opusplan* ]]; }
case "$tool" in
  Agent|Task)
    field model; m=$REPLY; field subagent_type; t=$REPLY
    { [[ $m == *fable* ]] || [[ $t == *fable* ]]; } && refuse "never use the Fable model. Use sonnet or haiku; the stronger model only with the user's OK."
    if { [[ $t == helper-careful || $t == helper-heavy ]] || isopus "$m"; } && ! approved; then refuse "$NEEDOK"; fi ;;
  mcp__ccd_session__start_session)
    field proposal_id; [ -n "$REPLY" ] && exit 0   # an already-proposed card: checked when it was proposed
    field model; m=$REPLY
    [[ $m == *fable* ]] && refuse "never start a chat on the Fable model. Use a Sonnet model; the stronger model only with the user's OK."
    isopus "$m" && ! approved && refuse "$NEEDOK" ;;
esac
exit 0
