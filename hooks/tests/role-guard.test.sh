#!/bin/bash
# Tests for role-guard.sh. Portable bash. Run: bash hooks/tests/role-guard.test.sh  (throwaway state folder)
H=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d 2>/dev/null || mktemp -d -t roleguard)
export CLAUDE_GUARD_STATE="$T/state" TMPDIR="$T/tmp"; mkdir -p "$CLAUDE_GUARD_STATE" "$TMPDIR"
unset CLAUDE_PROJECT_DIR
pass=0 fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
S=s1
# expect <code> <label> <json> [event]
expect() {
  local want=$1 label=$2 js=$3 got
  printf '%s' "$js" | bash "$H/role-guard.sh" $4 >"$T/out" 2>"$T/err"; got=$?
  [ "$got" = "$want" ] && ok || bad "$label (want exit $want, got $got: $(head -c 200 "$T/err"))"
}
reset() { rm -f "$CLAUDE_GUARD_STATE"/*; }
has() { [ -f "$CLAUDE_GUARD_STATE/$1-$S" ]; }
sub() { # <agent_type> <reply>  (SubagentStop)
  printf '{"session_id":"%s","agent_id":"a9","agent_type":"%s","hook_event_name":"SubagentStop","last_assistant_message":"%s"}' "$S" "$1" "$2"; }
agentstart() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"subagent_type":"%s","prompt":"x"}}' "$S" "$1"; }
ps_f() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"PowerShell","tool_input":{"command":"%s"}}' "$S" "$1"; }
post() { # <subagent_type> <model> <prompt> <reply>  (PostToolUse, no longer used for markers)
  printf '{"session_id":"%s","hook_event_name":"PostToolUse","tool_name":"Agent","tool_input":{"subagent_type":"%s","model":"%s","prompt":"%s"},"tool_response":{"status":"completed","content":[{"type":"text","text":"%s"}]}}' "$S" "$1" "$2" "$3" "$4"; }
exitplan() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"ExitPlanMode","tool_input":{"plan":"%s"}}' "$S" "$1"; }
edit() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"%s","permission_mode":"%s","tool_input":{"file_path":"%s"}}' "$S" "${2:-Edit}" "${3:-default}" "$1"; }
edit_h() { printf '{"session_id":"%s","agent_id":"a1","agent_type":"helper-medium","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$S" "$1"; }
bash_f() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$S" "$1"; }
bash_a() { printf '{"session_id":"%s","agent_id":"a1","agent_type":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$S" "$1" "$2"; }
stop() { printf '{"session_id":"%s","hook_event_name":"Stop","stop_hook_active":%s}' "$S" "${1:-false}"; }
start() { printf '{"session_id":"%s","hook_event_name":"SessionStart","source":"startup"%s}' "$S" "${1:+,\"model\":\"$1\"}"; }
CODE=/Users/r/code/app/src/app.js

echo "== SubagentStop markers"
reset
expect 0 "planner reply saved at SubagentStop" "$(sub helper-planner '# Plan\\n\\n1. Build **it**')"
has planner && ok || bad "planner-<sid> not written"
grep -q 'Build' "$CLAUDE_GUARD_STATE/planner-$S" 2>/dev/null && ok || bad "planner text missing"
reset
expect 0 "launched text at PostToolUse" "$(post helper-planner opus 'brief' 'Async agent launched. You will be notified')"
has planner && bad "launched text saved as plan" || ok
expect 0 "reviewer" "$(sub helper-reviewer ok)"; has reviewed && ok || bad "reviewed not written"
for t in helper-light helper-medium helper-builder; do rm -f "$CLAUDE_GUARD_STATE/built-$S"; expect 0 "$t" "$(sub $t done)"; has built && ok || bad "$t: built not written"; done
expect 0 "check run" "$(sub helper-check done)"; has checked && ok || bad "checked not written"
rm -f "$CLAUDE_GUARD_STATE/built-$S"
expect 0 "scout not a builder" "$(sub helper-scout done)"; has built && bad "scout counted as builder" || ok
expect 0 "general-purpose not a builder" "$(sub general-purpose done)"; has built && bad "gp counted" || ok

echo "== Agent start needs a plan"
reset
for t in helper-light helper-medium helper-builder; do expect 2 "$t without planner" "$(agentstart $t)"; done
grep -q 'helper-planner first' "$T/err" && ok || bad "planner-first message missing"
expect 0 "planner start allowed" "$(agentstart helper-planner)"
expect 0 "scout start allowed" "$(agentstart helper-scout)"
sub helper-planner 'Plan. Size: large' | bash "$H/role-guard.sh"
for t in helper-light helper-medium helper-builder; do expect 0 "$t after planner" "$(agentstart $t)"; done

echo "== ExitPlanMode"
reset
expect 2 "no planner reply: refused" "$(exitplan 'Plan: do it')"
grep -q 'word for word' "$T/err" && ok || bad "message missing"
sub helper-planner '# Plan\\n\\n1. Build **it**\\n2. Review: Sonnet' | bash "$H/role-guard.sh"
expect 0 "same text, other layout" "$(exitplan 'Plan\\n1) build it\\n2) Review:  Sonnet')"
expect 2 "different text" "$(exitplan 'Plan: build it differently')"
printf '{"session_id":"%s","agent_id":"a1","hook_event_name":"PreToolUse","tool_name":"ExitPlanMode","tool_input":{"plan":"x"}}' "$S" > "$T/h.json"
expect 0 "helper not gated" "$(cat "$T/h.json")"
mkdir -p "$T/home/.claude/plans"; echo 'Totally other plan' > "$T/home/.claude/plans/p.md"
touch -t 202001010000 "$CLAUDE_GUARD_STATE/planner-$S"
printf '%s' "$(exitplan '')" > "$T/e.json"; HOME=$T/home bash "$H/role-guard.sh" < "$T/e.json" >/dev/null 2>&1; [ $? = 2 ] && ok || bad "newer plans file not compared"
touch -t 203001010000 "$CLAUDE_GUARD_STATE/planner-$S"
HOME=$T/home bash "$H/role-guard.sh" < "$T/e.json" >/dev/null 2>&1; [ $? = 0 ] && ok || bad "stale plans file used"

echo "== Edit / Write from the front chat"
reset
expect 2 "Edit refused" "$(edit $CODE)"
expect 2 "Write refused" "$(edit $CODE Write)"
expect 2 "MultiEdit refused" "$(edit $CODE MultiEdit)"
expect 2 "NotebookEdit refused" "$(edit /x/a.ipynb NotebookEdit)"
grep -q "Sonnet builder" "$T/err" && ok || bad "edit message missing"
expect 0 "plan file in plan mode" "$(edit /Users/r/.claude/plans/p.md Write plan)"
expect 2 "plan file outside plan mode" "$(edit /Users/r/.claude/plans/p.md Write default)"
expect 2 "code file in plan mode" "$(edit $CODE Write plan)"
expect 0 "memory note" "$(edit /Users/r/.claude/projects/-Users-r-Projects/memory/note.md Write)"
expect 0 "builder (agent_id) may edit" "$(edit_h $CODE)"
expect 0 "front chat handover edit" "$(edit /Users/r/Projects/admin/handovers/task.md Write)"
expect 0 "front chat ACTIVE.md edit" "$(edit /Users/r/Projects/ACTIVE.md Edit)"

echo "== Bash"
reset
for c in 'ls -la' 'git status' 'git log --oneline | head' 'cat a.txt > /dev/null' 'grep -rn foo . 2>/dev/null' 'ls 2>&1 | head' 'echo "a > b"' 'git diff --stat' 'sed -n 1,5p f' 'git add -A' 'git commit -m x' 'git push origin main' 'git -C /x commit -m y'; do
  expect 0 "front allows: $c" "$(bash_f "$c")"; done
for c in 'echo hi > out.txt' 'echo hi >> out.txt' 'sed -i s/a/b/ f' "sed -i '' s/a/b/ f" 'ls | tee f' 'cp a b' 'mv a b' 'rm -f a' 'git merge x' 'git checkout -b new' 'git reset --hard' 'perl -pi -e s/a/b/ f' 'ls && rm a' 'git restore f' 'git stash' 'git checkout -- f' 'touch f' 'mkdir d' 'ln -s a b' 'python3 -c "open(1)"' 'python -c x'; do
  expect 2 "front blocks: $c" "$(bash_f "$c")"; done
expect 2 "planner blocks rm" "$(bash_a helper-planner 'rm a')"
expect 2 "reviewer blocks redirect" "$(bash_a helper-reviewer 'echo x > f')"
expect 2 "planner blocks git commit" "$(bash_a helper-planner 'git commit -m x')"
expect 2 "reviewer blocks git push" "$(bash_a helper-reviewer 'git push')"
for c in 'Set-Content -Path a -Value b' 'Out-File a' 'Add-Content a b' 'New-Item a' 'Copy-Item a b' 'Move-Item a b' 'Remove-Item a' 'Get-Content a | Set-Content b'; do
  expect 2 "PowerShell blocks: $c" "$(ps_f "$c")"; done
expect 0 "PowerShell allows Get-ChildItem" "$(ps_f 'Get-ChildItem')"
expect 0 "planner allows ls" "$(bash_a helper-planner 'ls')"
expect 0 "builder may rm" "$(bash_a helper-medium 'rm a')"
expect 0 "builder may redirect" "$(bash_a helper-medium 'echo x > f')"

echo "== Stop"
reset
expect 0 "nothing built" "$(stop)"
sub helper-planner 'Plan. Size: large' | bash "$H/role-guard.sh"
sub helper-medium done | bash "$H/role-guard.sh"
expect 2 "built, never reviewed" "$(stop)"
grep -q 'start helper-reviewer' "$T/err" && ok || bad "stop message missing"
expect 0 "second stop (stop_hook_active) passes" "$(stop true)"
sub helper-check ok | bash "$H/role-guard.sh"
expect 2 "normal plan: check run does not replace review" "$(stop)"
sub helper-reviewer ok | bash "$H/role-guard.sh"
expect 0 "reviewed after built" "$(stop)"
sub helper-light done | bash "$H/role-guard.sh"
expect 2 "builder after review" "$(stop)"
reset
sub helper-planner 'Plan. Size: small, one file' | bash "$H/role-guard.sh"
sub helper-light done | bash "$H/role-guard.sh"
expect 2 "small route, no check yet" "$(stop)"
sub helper-check ok | bash "$H/role-guard.sh"
expect 0 "small route, check run after build" "$(stop)"
sub helper-light done | bash "$H/role-guard.sh"
expect 2 "small route, build after the check" "$(stop)"

echo "== SessionStart"
reset
expect 0 "sonnet quiet" "$(start claude-sonnet-5-5)"; [ -z "$(cat "$T/out")" ] && ok || bad "sonnet printed output"
expect 0 "opus warns" "$(start claude-opus-5)"
grep -q '/model sonnet' "$T/out" && grep -q 'model picker' "$T/out" && ok || bad "warning text missing"
expect 0 "no model field: silent + log" "$(start)"; [ -z "$(cat "$T/out")" ] && [ -s "$CLAUDE_GUARD_STATE/role-guard.log" ] && ok || bad "no-model fallback"

echo "== event as arg, no session"
expect 2 "arg PreToolUse edit" "$(edit $CODE)" PreToolUse
expect 0 "no session id allowed" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/x"}}'

rm -rf "$T"
echo "role-guard: $pass passed, $fail failed"; [ "$fail" = 0 ]
