#!/bin/bash
# Checks Claude's final reply against the plain-talk and finish rules (shared rules 1.6, 1.7, 5, 7). Bash only, no jq, no python, no model call.
# One script, two events:
#   PostToolUse (Edit|Write|MultiEdit|NotebookEdit) -> records the edited file path for this chat/turn (state folder, changed-<session>)
#   Stop                                            -> checks the reply; if something is wrong, sends it back ONCE ({"decision":"block"}) so Claude rewrites it
# Checks: (a) banned words outside code, backticks, paths and URLs; (b) too long; (c) files changed but no "Review:" line;
#         (d) reply says done but changed files are uncommitted or the branch is unpushed. The record is cleared after every Stop.
# Helper events (agent_id set) are ignored. stop_hook_active true -> never sends back twice.

# ---- easy to edit -------------------------------------------------------------------------------------------------
BANNED='subagents?|compacting|compaction|hooks?|worktrees?|MCP|context window|tokens|harness|house rules'

MAXLINES=15    # more than this many non-empty prose lines (outside code blocks and tables) -> too long
# files that never need a Review line (path patterns, forward slashes)
EXEMPT='/handovers/|/memory/|/\.claude/plans/|/scratchpad/|/tmp/|/ACTIVE\.md$'
FINISH='\b(done|finished|all set|complete|completed|pushed)\b'
# -------------------------------------------------------------------------------------------------------------------
in=$(cat)  # $(</dev/stdin) reads nothing from the app's pipe on Windows; cat works on both
get() { REPLY=; local r='"'"$1"'"[[:space:]]*:[[:space:]]*"([^"]*)"'; [[ $in =~ $r ]] && REPLY=${BASH_REMATCH[1]}; }
get agent_id; [ -n "$REPLY" ] && exit 0
get hook_event_name; ev=$REPLY
get session_id; sid=${REPLY//[^A-Za-z0-9-]/}; [ -z "$sid" ] && exit 0
d=${CLAUDE_GUARD_STATE:-$HOME/.claude/guard-state}; mkdir -p "$d" 2>/dev/null
rec="$d/changed-$sid"

if [ "$ev" = PostToolUse ]; then
  r='"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  [[ $in =~ $r ]] || exit 0
  p=${BASH_REMATCH[2]//\\\\//}; p=${p//\\//}   # JSON-escaped backslashes -> forward slashes
  [ -z "$p" ] && exit 0
  grep -qxF -- "$p" "$rec" 2>/dev/null || printf '%s\n' "$p" >> "$rec"
  exit 0
fi
[ "$ev" = Stop ] || exit 0

# ---- Stop ----
changed=; [ -f "$rec" ] && changed=$(cat "$rec")
: > "$rec" 2>/dev/null          # the record covers one turn only
r='"stop_hook_active"[[:space:]]*:[[:space:]]*true'; [[ $in =~ $r ]] && exit 0
r='"last_assistant_message"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'; [[ $in =~ $r ]] || exit 0
m=${BASH_REMATCH[1]}
m=${m//\\\\/$'\001'}; m=${m//\\n/$'\n'}; m=${m//\\r/}; m=${m//\\t/ }; m=${m//\\\"/\"}; m=${m//\\\//\/}; m=${m//$'\001'/\\}

# prose = reply without fenced code blocks; plain = prose without `inline code`, URLs and paths
prose=$(printf '%s\n' "$m" | awk '/^[[:space:]]*```/ {f=!f; next} !f')
plain=$(printf '%s\n' "$prose" | sed -E 's/`[^`]*`//g; s#[A-Za-z][A-Za-z0-9+.-]*://[^[:space:]]*##g; s#[^[:space:]]*[/\\][^[:space:]]*##g')
reasons=()

# a. banned words
bad=$(printf '%s\n' "$plain" | grep -Eiow "$BANNED" | tr 'A-Z' 'a-z' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
[ -n "$bad" ] && reasons+=("Plain words only: rewrite without these terms: $bad (say 'a helper working in the background', 'clear out old conversation', 'automatic check', 'shared rules', etc.).")

# b. length (tables and blank lines do not count)
n=$(printf '%s\n' "$prose" | grep -Ev '^[[:space:]]*$|^[[:space:]]*\|' | wc -l | tr -d ' ')
[ "${n:-0}" -gt "$MAXLINES" ] && reasons+=("Too long ($n lines): 1-3 lines unless asked for detail. Shorten it.")

# c. Review line when real files changed this turn
need=
if [ -n "$changed" ]; then
  while IFS= read -r f; do [ -n "$f" ] && ! printf '%s' "$f" | grep -Eq "$EXEMPT" && need=1; done <<< "$changed"
fi
if [ -n "$need" ] && ! printf '%s\n' "$m" | grep -Eiq '^[[:space:]]*(\*\*)?Review:'; then
  reasons+=("Files were changed this turn but the reply has no 'Review:' line. Add one line starting 'Review:' saying what was checked and what was fixed.")
fi

# d. says done, but changed files are not committed/pushed
if [ -n "$changed" ] && printf '%s\n' "$plain" | grep -Eiq "$FINISH"; then
  repos=; loose=
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ ! -e "$f" ] && [[ $f =~ ^([A-Za-z]):/(.*)$ ]]; then lc=$(printf '%s' "${BASH_REMATCH[1]}" | tr 'A-Z' 'a-z'); f="/$lc/${BASH_REMATCH[2]}"; fi
    [ -e "$f" ] || continue
    dir=$(dirname "$f")
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || continue
    [ -n "$(git -C "$dir" status --porcelain -- "$f" 2>/dev/null)" ] && loose="$loose ${f##*/}"
    case "
$repos
" in *"
$top
"*) ;; *) repos="$repos
$top";; esac
  done <<< "$changed"
  while IFS= read -r top; do
    [ -z "$top" ] && continue
    a=$(git -C "$top" rev-list --count '@{u}..HEAD' 2>/dev/null); [ "${a:-0}" -gt 0 ] && loose="$loose (${top##*/}: $a commit(s) not pushed)"
  done <<< "$repos"
  [ -n "$loose" ] && reasons+=("The reply says the work is done but this is not saved:$loose. Commit and push first, or say why not.")
fi

[ ${#reasons[@]} -eq 0 ] && exit 0
msg=; for x in "${reasons[@]}"; do msg="$msg$x "; done
msg=${msg% }; msg=${msg//\\/\\\\}; msg=${msg//\"/\\\"}
printf '{"decision":"block","reason":"%s"}\n' "$msg"
exit 0
