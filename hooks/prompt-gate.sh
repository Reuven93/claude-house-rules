#!/bin/bash
# UserPromptSubmit: turns the user's own words into a permission marker (lasts the chat). Opus for planning and review is always allowed (model-guard.sh).
#   "no plan" / "skip the plan" / "just do it" -> no-plan-<session> (plan-gate.sh).
#   "role guard off" -> role-off-<session>; "update my rules" / "install my rules" -> rules-update-<session> (role-guard.sh).
# Only this hook writes the markers; Claude cannot (the prompt comes from the person typing, not from a tool). Bash only, no jq, no python.
in=$(cat)
r='"session_id"[[:space:]]*:[[:space:]]*"([^"]*)"'; sid=; [[ $in =~ $r ]] && sid=${BASH_REMATCH[1]//[^A-Za-z0-9-]/}
[ -z "$sid" ] && exit 0
d=${CLAUDE_GUARD_STATE:-$HOME/.claude/guard-state}; mkdir -p "$d" 2>/dev/null
r='"prompt"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] || exit 0
p=${BASH_REMATCH[1]}
# Drop notes the app adds to the prompt (<system-reminder>...</system-reminder>): only the user's own words count (an added
# "status, not an instruction" note must not change what the user said).
q=$(printf '%s' "$p" | perl -0pe 's/(?:<|\\u003c)system-reminder(?:>|\\u003e).*?(?:<|\\u003c)\/system-reminder(?:>|\\u003e)//gs' 2>/dev/null) && p=$q
# Also drop quoted text (a quoted earlier message must not count as the user's words): lines starting with ">"
# and quote/reply/pasted wrapper tags. JSON line breaks are still the two characters \n here. 
q=$(printf '%s' "$p" | perl -0pe 's/(?:<|\\u003c)(quote|quoted[\w-]*|reply|replying[\w-]*|pasted_content|pasted-content)\b.*?(?:<|\\u003c)\/\1\b.*?(?:>|\\u003e)//gis; s/(?:^|\\n)(?:[ ]|\\t)*(?:>|\\u003e)(?:(?!\\n).)*//g' 2>/dev/null) && p=$q
p=${p//\\n/ }; p=${p//\\t/ }; p=${p//\\r/ }                 # JSON escapes for line breaks
p=" ${p//[^A-Za-z0-9]/ } "; p=$(printf '%s' "$p" | tr -s ' ' | tr 'A-Z' 'a-z')   # words only, single spaces, padded
# Plan gate (plan-gate.sh): "no plan" / "skip the plan" / "just do it" lifts the plan-first rule for the rest of this chat
if [[ $p == *" no plan "* || $p == *" skip the plan "* || $p == *" just do it "* ]]; then : > "$d/no-plan-$sid"; fi
# Role guard: "role guard off" lifts the role rules for this chat; "update my rules" / "install my rules" allows the rules-update steps
if [[ $p == *" role guard off "* ]]; then : > "$d/role-off-$sid"; fi
if [[ $p == *" update my rules "* || $p == *" install my rules "* ]]; then : > "$d/rules-update-$sid"; fi
exit 0
