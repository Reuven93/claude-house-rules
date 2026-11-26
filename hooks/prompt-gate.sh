#!/bin/bash
# UserPromptSubmit: turns the user's own words into permission markers (OK lasts the chat).
#   "opus"/"stronger model" + yes/ok/approve/go ahead/use, or exactly "ok opus"
#                                                  -> opus-ok-<session>: the stronger model may be started for the rest of this chat (model-guard.sh);
#                                                     "don't use / no opus / never opus" takes it back
#   "no plan" / "skip the plan" / "just do it" -> no-plan-<session> (plan-gate.sh).
# Only this hook writes the markers; Claude cannot (the prompt comes from the person typing, not from a tool). Bash only, no jq, no python.
in=$(cat)
r='"session_id"[[:space:]]*:[[:space:]]*"([^"]*)"'; sid=; [[ $in =~ $r ]] && sid=${BASH_REMATCH[1]//[^A-Za-z0-9-]/}
[ -z "$sid" ] && exit 0
d=${CLAUDE_GUARD_STATE:-$HOME/.claude/guard-state}; mkdir -p "$d" 2>/dev/null
r='"prompt"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] || exit 0
p=${BASH_REMATCH[1]}
# Drop notes the app adds to the prompt (<system-reminder>...</system-reminder>): only the user's own words count (once
# an added "status, not an instruction" note cancelled "ok opus").
q=$(printf '%s' "$p" | perl -0pe 's/(?:<|\\u003c)system-reminder(?:>|\\u003e).*?(?:<|\\u003c)\/system-reminder(?:>|\\u003e)//gs' 2>/dev/null) && p=$q
# Also drop quoted text (a quoted earlier message with "don't"/"never"/"without" cancelled "ok opus"): lines starting with ">"
# and quote/reply/pasted wrapper tags. JSON line breaks are still the two characters \n here. 
q=$(printf '%s' "$p" | perl -0pe 's/(?:<|\\u003c)(quote|quoted[\w-]*|reply|replying[\w-]*|pasted_content|pasted-content)\b.*?(?:<|\\u003c)\/\1\b.*?(?:>|\\u003e)//gis; s/(?:^|\\n)(?:[ ]|\\t)*(?:>|\\u003e)(?:(?!\\n).)*//g' 2>/dev/null) && p=$q
p=${p//\\n/ }; p=${p//\\t/ }; p=${p//\\r/ }                 # JSON escapes for line breaks
p=" ${p//[^A-Za-z0-9]/ } "; p=$(printf '%s' "$p" | tr -s ' ' | tr 'A-Z' 'a-z')   # words only, single spaces, padded
# Plan gate (plan-gate.sh): "no plan" / "skip the plan" / "just do it" lifts the plan-first rule for the rest of this chat
if [[ $p == *" no plan "* || $p == *" skip the plan "* || $p == *" just do it "* ]]; then : > "$d/no-plan-$sid"; fi
ok=0
if [ "$p" = " ok opus " ]; then ok=1
elif [[ $p == *" opus "* || $p == *" stronger model "* ]] &&
     [[ $p == *" yes "* || $p == *" ok "* || $p == *" okay "* || $p == *" approve "* || $p == *" approved "* || $p == *" go ahead "* || $p == *" use "* ]] &&
     ! [[ $p == *" don t "* || $p == *" dont "* || $p == *" do not "* || $p == *" never "* || $p == *" no opus "* || $p == *" without "* ]]; then ok=1
fi
[ "$ok" = 1 ] && : > "$d/opus-ok-$sid"
# The user takes the OK back ("don't use opus", "no opus", "never opus")
if [ "$ok" = 0 ] && [[ $p == *" opus "* || $p == *" stronger model "* ]] &&
   [[ $p == *" don t "* || $p == *" dont "* || $p == *" do not "* || $p == *" never "* || $p == *" no opus "* || $p == *" without "* ]]; then
  rm -f "$d/opus-ok-$sid"; fi
exit 0
