#!/bin/bash
# Tests for plan-gate.sh (and the "no plan" phrases in prompt-gate.sh). Portable bash, no jq/python.
# Run: bash hooks/tests/plan-gate.test.sh      (throwaway state folder; touches nothing real)
H=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d 2>/dev/null || mktemp -d -t plangate)
export CLAUDE_GUARD_STATE="$T/state" TMPDIR="$T/tmp"; mkdir -p "$CLAUDE_GUARD_STATE" "$TMPDIR"
unset CLAUDE_PROJECT_DIR
pass=0 fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
# expect <code> <label> <json>
expect() {
  local want=$1 label=$2 js=$3 got
  printf '%s' "$js" | bash "$H/plan-gate.sh" >/dev/null 2>"$T/err"; got=$?
  [ "$got" = "$want" ] && ok || bad "$label (want exit $want, got $got: $(head -c 200 "$T/err"))"
}
SID=s1; TR="$T/none.jsonl"
edit() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"%s","transcript_path":"%s","permission_mode":"%s","tool_input":{"file_path":"%s"}}' "$SID" "${2:-Edit}" "$TR" "${3:-default}" "$1"; }
helper() { printf '{"session_id":"%s","agent_id":"a1","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$SID" "$1"; }
exitplan() { printf '{"session_id":"%s","hook_event_name":"%s","tool_name":"ExitPlanMode","tool_input":{"plan":"%s"}}' "$SID" "${2:-PreToolUse}" "$1"; }
prompt() { printf '{"session_id":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$SID" "$1" | bash "$H/prompt-gate.sh"; }
reset() { rm -f "$CLAUDE_GUARD_STATE"/*; }
CODE=/Users/r/Projects/repos/app/src/app.js
normal() { printf '%s\n' '{"type":"user","message":{"role":"user","content":"please fix the bug"}}' > "$TR"; }
normal

echo "== edits"
reset
expect 2 "edit before plan blocked" "$(edit $CODE)"
expect 2 "Write before plan blocked" "$(edit $CODE Write)"
expect 0 "Bash never gated" "$(printf '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}')"
expect 0 "handover edit allowed" "$(edit /Users/r/Projects/admin/handovers/task.md)"
expect 0 "memory edit allowed" "$(edit /Users/r/.claude/projects/-Users-r-Projects/memory/MEMORY.md)"
expect 0 "plan file edit allowed" "$(edit /Users/r/.claude/plans/noble-plan.md)"
expect 0 "ACTIVE.md allowed" "$(edit /Users/r/Projects/ACTIVE.md)"
expect 0 "scratchpad allowed" "$(edit /private/tmp/claude-502/x/scratchpad/a.sh)"
expect 0 "/tmp allowed" "$(edit /tmp/a.txt)"
expect 0 "plan mode allowed" "$(edit $CODE Write plan)"
expect 0 "helper allowed" "$(helper $CODE)"
expect 0 "Windows handover path allowed" "$(edit 'C:\\Users\\R\\Projects\\admin\\handovers\\task.md')"
expect 0 "Windows memory path allowed" "$(edit 'C:\\Users\\R\\.claude\\projects\\p\\memory\\a.md')"
expect 2 "Windows code path blocked" "$(edit 'C:\\Users\\R\\repos\\app\\src\\app.js')"

echo "== markers"
reset
expect 0 "plan approved writes marker" "$(exitplan x PostToolUse)"
[ -f "$CLAUDE_GUARD_STATE/plan-ok-$SID" ] && ok || bad "plan-ok marker missing"
expect 0 "edit after plan-ok allowed" "$(edit $CODE)"
reset
for ph in "no plan" "Skip the plan please" "just do it"; do
  reset; prompt "$ph"
  [ -f "$CLAUDE_GUARD_STATE/no-plan-$SID" ] && ok || bad "prompt '$ph' should write no-plan"
  expect 0 "edit after '$ph' allowed" "$(edit $CODE)"
done
reset; prompt "please plan this carefully"
[ -f "$CLAUDE_GUARD_STATE/no-plan-$SID" ] && bad "ordinary prompt wrote no-plan" || ok
expect 2 "still blocked after ordinary prompt" "$(edit $CODE)"

echo "== chat start"
reset
printf '%s\n' '{"type":"user","message":{"role":"user","content":"Carry on from /Users/r/Projects/admin/handovers/x.md"}}' > "$TR"
expect 0 "Carry on from chat allowed" "$(edit $CODE)"
printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Carry on from /x.md"}]}}' > "$TR"
expect 0 "Carry on from (content array) allowed" "$(edit $CODE)"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"please fix the bug"}}' > "$TR"
expect 2 "normal chat blocked" "$(edit $CODE)"
rm -f "$TR"
expect 0 "missing transcript allowed" "$(edit $CODE)"

echo "== plans"
RV='Review: Sonnet reviewer, docs check.'
BUILD='Plan\n## Builders\n| piece | files | helper | group |\n|---|---|---|---|\n| A | a.sh | medium | 1 |\nHandover check: no open tasks overlap.\n'
expect 2 "build plan without Builders table blocked" "$(exitplan "Build the gate by editing a.sh. Handover check: clear. $RV")"
expect 2 "build plan without handover check blocked" "$(exitplan "Plan\\n## Builders\\n| p | f |\\n|--|--|\\n| A | a.sh |\\n$RV")"
expect 2 "build plan without Review line blocked" "$(exitplan "${BUILD}")"
expect 0 "build plan with all parts passes" "$(exitplan "${BUILD}${RV}")"
expect 0 "single builder with reason passes" "$(exitplan "Implement x. One builder: one file. Open-tasks check: clear. $RV")"
expect 0 "research plan with only Review line passes" "$(exitplan "Look up the rates in the connector and summarise. $RV")"
expect 2 "research plan without Review line blocked" "$(exitplan "Look up the rates in the connector and summarise.")"
out=$(printf '%s' "$(exitplan "Build it")" | bash "$H/plan-gate.sh" 2>&1 >/dev/null); [[ $out == *Builders* && $out == *Review* ]] && ok || bad "refusal lists what is missing: $out"

rm -rf "$T"
echo "plan-gate tests: $pass passed, $fail failed"
[ "$fail" = 0 ]
