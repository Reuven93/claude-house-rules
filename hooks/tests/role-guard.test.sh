#!/bin/bash
# Tests for role-guard.sh. Portable bash. Run: bash .claude/hooks/tests/role-guard.test.sh  (throwaway state folder)
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
CODE=/Users/r/Projects/repos/app/src/app.js

echo "== SubagentStop markers"
reset
expect 0 "planner reply saved at SubagentStop" "$(sub helper-planner '# Plan\\n\\n1. Build **it**')"
has planner && ok || bad "planner-<sid> not written"
grep -q 'Build' "$CLAUDE_GUARD_STATE/planner-$S" 2>/dev/null && ok || bad "planner text missing"
reset
expect 0 "launched text at PostToolUse" "$(post helper-planner opus 'TIER: 3' 'Async agent launched. You will be notified')"
has planner && bad "launched text saved as plan" || ok
expect 0 "reviewer" "$(sub helper-reviewer ok)"; has reviewed && ok || bad "reviewed not written"
for t in helper-light helper-medium helper-builder; do rm -f "$CLAUDE_GUARD_STATE/built-$S"; expect 0 "$t" "$(sub $t done)"; has built && ok || bad "$t: built not written"; done
expect 0 "check run" "$(sub helper-check done)"; has checked && ok || bad "checked not written"
rm -f "$CLAUDE_GUARD_STATE/built-$S"
expect 0 "scout not a builder" "$(sub helper-scout done)"; has built && bad "scout counted as builder" || ok
expect 0 "general-purpose is a builder" "$(sub general-purpose done)"; has built && ok || bad "gp not counted as builder"
for t in Explore claude-code-guide web-fetch; do rm -f "$CLAUDE_GUARD_STATE/built-$S"; expect 0 "$t read-only" "$(sub $t done)"; has built && bad "$t counted as builder" || ok; done

echo "== Builder start gate"
reset
wk() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"Workflow","tool_input":{"script":"x"}}' "$S"; }
ss() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"mcp__ccd_session__start_session","tool_input":{"prompt":"%s"}}' "$S" "$1"; }
for t in helper-light helper-medium helper-builder general-purpose; do expect 2 "$t without plan" "$(agentstart $t)"; done
expect 2 "helper type empty (general-purpose default)" "$(printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"prompt":"x"}}' "$S")"
grep -q 'helper-planner plans' "$T/err" && ok || bad "gate message missing"
expect 2 "Workflow without plan" "$(wk)"
expect 2 "start_session ROLE: builder without plan" "$(ss 'ROLE: builder\\nbuild it')"
expect 0 "start_session other role allowed" "$(ss 'ROLE: planner\\nplan it')"
for t in helper-planner helper-reviewer helper-scout helper-check Explore claude-code-guide web-fetch; do expect 0 "$t start allowed" "$(agentstart $t)"; done
sub helper-planner 'Plan. Size: large' | bash "$H/role-guard.sh"
expect 2 "planner reply but no plan-ok" "$(agentstart helper-medium)"
touch -t 202001010000 "$CLAUDE_GUARD_STATE/planner-$S"; touch "$CLAUDE_GUARD_STATE/plan-ok-$S"
for t in helper-light helper-medium helper-builder general-purpose; do expect 0 "$t after plan-ok" "$(agentstart $t)"; done
expect 0 "Workflow after plan-ok" "$(wk)"
expect 0 "start_session builder after plan-ok" "$(ss 'ROLE: builder')"
touch -t 203001010000 "$CLAUDE_GUARD_STATE/planner-$S"
expect 2 "plan-ok older than planner reply" "$(agentstart helper-medium)"
touch -t 202501010000 "$CLAUDE_GUARD_STATE/planner-$S" "$CLAUDE_GUARD_STATE/plan-ok-$S"
expect 0 "plan-ok same mtime as planner reply counts" "$(agentstart helper-medium)"
touch -t 203001010000 "$CLAUDE_GUARD_STATE/planner-$S"
reset
touch "$CLAUDE_GUARD_STATE/plan-ok-$S"
expect 2 "plan-ok without planner reply" "$(agentstart helper-medium)"
reset; touch "$CLAUDE_GUARD_STATE/no-plan-$S"
expect 0 "no-plan marker" "$(agentstart helper-medium)"
reset; touch "$CLAUDE_GUARD_STATE/rules-update-$S"
expect 0 "rules-update marker" "$(agentstart helper-medium)"
reset
sub helper-medium done | bash "$H/role-guard.sh"
expect 2 "built, not reviewed: no new builder" "$(agentstart helper-medium)"
sub helper-reviewer ok | bash "$H/role-guard.sh"
expect 0 "reviewed after built: builder allowed" "$(agentstart helper-medium)"
sub helper-light done | bash "$H/role-guard.sh"
expect 2 "built after review again" "$(agentstart helper-medium)"
printf '{"session_id":"%s","agent_id":"a1","agent_type":"helper-planner","hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"subagent_type":"helper-medium"}}' "$S" > "$T/h.json"
expect 0 "helper starting a helper not gated here" "$(cat "$T/h.json")"

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
for c in 'ls -la' 'git status' 'git log --oneline | head' 'cat a.txt > /dev/null' 'grep -rn foo . 2>/dev/null' 'ls 2>&1 | head' 'echo \"a > b\"' 'git diff --stat' 'git add -A' 'git commit -m x' 'git push origin main' 'git -C /x commit -m y' 'git merge feat' 'git pull --ff-only' 'git fetch' 'git branch' 'git branch -a' 'git branch -d old' 'git branch --merged main' 'git worktree list' 'git worktree remove /x' 'git worktree prune' 'git rev-parse HEAD' 'git ls-files' 'git config --get user.name' 'git show HEAD' 'find . -name a' 'sort f' 'wc -l f | head' 'head -3 f; tail -3 f' 'pwd && date' 'which git' 'cd /x && ls' 'stat f' 'diff a b' 'printf hi' 'rg foo' 'bash /x/.claude/hooks/tidy.sh list' 'git commit -m \"a; rm b | c\"' 'echo \"$(date)\"' 'git log -1 $(git rev-parse HEAD)'; do
  expect 0 "front allows: $c" "$(bash_f "$c")"; done
for c in 'echo hi > out.txt' 'echo hi >> out.txt' 'sed -i s/a/b/ f' "sed -i '' s/a/b/ f" 'ls | tee f' 'cp a b' 'mv a b' 'rm -f a' 'git checkout -b new' 'git reset --hard' 'perl -pi -e s/a/b/ f' 'ls && rm a' 'git restore f' 'git stash' 'git checkout -- f' 'touch f' 'mkdir d' 'ln -s a b' 'python3 -c \"open(1)\"' 'python -c x'; do
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

echo "== Front chat allow-list bypasses"
reset
for c in 'bash -c \"echo hi\"' 'sh -c ls' 'dd if=a of=b' 'git apply p.diff' 'patch -p1 < x' 'tee f' 'python3 -c \"open(1)\"' 'node -e 1' 'curl http://x' 'awk 1 f' 'sed -n 1,5p f' 'eval ls' 'xargs rm' 'ls; rm a' 'ls | sh' 'ls & rm a' 'ls || rm a' 'ls $(rm a)' 'echo \"$(rm a)\"' 'echo `rm a`' 'cat <(rm a)' 'FOO=1 ls' '/bin/ls' 'l\s' 'git push --force' 'git push -f origin main' 'git push --force-with-lease' 'git push origin +main' 'git pull' 'git branch newb' 'git branch -D x' 'git branch -m a b' 'git worktree add /x' 'git config user.name x' 'git config --global x y' 'git clean -fd' 'git rebase main' 'git cherry-pick x' 'git checkout main' 'git tag x' 'git diff --output=f' 'find . -delete' 'find . -exec rm {} ;' 'find . -fprint f' 'sort -o f g' 'sort --output=f g' 'rg --pre cmd x' 'date -s 10:00' 'bash x.sh' 'bash /x/tidy.sh fix' 'node a.js' 'make'; do
  expect 2 "front refuses: $c" "$(bash_f "$c")"; done
for c in 'Get-ChildItem' 'Get-Content a' 'Select-String foo a' 'Test-Path a'; do expect 0 "PowerShell front allows: $c" "$(ps_f "$c")"; done
for c in 'sc a b' 'ni a' 'ri a' '[IO.File]::WriteAllText(a,b)' 'Get-Content a | Set-Content b' 'Invoke-Expression x' 'Set-Content a b' 'cmd /c dir'; do
  expect 2 "PowerShell front refuses: $c" "$(ps_f "$c")"; done
echo "== Read-only helpers (planner, reviewer, scout, check)"
for a in helper-planner helper-reviewer helper-scout helper-check; do
  for c in 'bash -c \"echo hi\"' 'sh -c ls' 'dd if=a of=b' 'git apply p.diff' 'patch -p1 < x' 'tee f' 'ls | tee f' 'python3 -c \"open(1)\"' 'node -e 1' 'echo x > f' 'cp a b' 'sed -i s/a/b/ f' 'git commit -m x'; do
    expect 2 "$a refuses: $c" "$(bash_a $a "$c")"; done
  for c in 'sc a b' 'ni a' 'ri a' '[IO.File]::WriteAllText(a,b)' '[System.IO.File]::WriteAllText(a,b)' 'Set-Content a b'; do
    expect 2 "$a PowerShell refuses: $c" "$(printf '{"session_id":"%s","agent_id":"a1","agent_type":"%s","hook_event_name":"PreToolUse","tool_name":"PowerShell","tool_input":{"command":"%s"}}' "$S" "$a" "$c")"; done
  expect 0 "$a allows ls" "$(bash_a $a 'ls -la | head')"
  expect 0 "$a allows git log" "$(bash_a $a 'git log --oneline')"
  expect 2 "$a cannot Edit" "$(printf '{"session_id":"%s","agent_id":"a1","agent_type":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$S" "$a" "$CODE")"
done
expect 0 "Explore not command-checked" "$(bash_a Explore 'rm a')"
expect 0 "general-purpose helper may write" "$(bash_a general-purpose 'echo x > f')"

echo "== Log-only mode and role-off"
reset
printf '%s' "$(edit $CODE)" > "$T/l.json"
ROLE_GUARD_LOG_ONLY=1 bash "$H/role-guard.sh" < "$T/l.json" >/dev/null 2>&1; [ $? = 0 ] && ok || bad "log-only should allow"
grep -q 'would refuse' "$CLAUDE_GUARD_STATE/role-guard.log" && grep -q "sid=$S ev=PreToolUse type=front" "$CLAUDE_GUARD_STATE/role-guard.log" && ok || bad "log-only lines missing"
bash "$H/role-guard.sh" < "$T/l.json" >/dev/null 2>&1; [ $? = 2 ] && ok || bad "refuses without log-only"
touch "$CLAUDE_GUARD_STATE/role-off-$S"
bash "$H/role-guard.sh" < "$T/l.json" >/dev/null 2>&1; [ $? = 0 ] && ok || bad "role-off should allow"
expect 0 "role-off allows builder start" "$(agentstart helper-medium)"
expect 0 "role-off allows rm" "$(bash_f 'rm a')"
rm -f "$CLAUDE_GUARD_STATE/role-off-$S"

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
