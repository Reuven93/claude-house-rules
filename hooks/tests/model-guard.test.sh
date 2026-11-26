#!/bin/bash
# Tests for model-guard.sh (roles for models). Portable bash, no jq/python. Run: bash hooks/tests/model-guard.test.sh
H=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d 2>/dev/null || mktemp -d -t modeltests)
export CLAUDE_GUARD_STATE="$T/state"; mkdir -p "$CLAUDE_GUARD_STATE"
unset CLAUDE_PROJECT_DIR
SID=test-session-1
pass=0 fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
expect() { local want=$1 label=$2 js=$3 got
  printf '%s' "$js" | bash "$H/model-guard.sh" >/dev/null 2>"$T/err"; got=$?
  [ "$got" = "$want" ] && ok || bad "$label (want exit $want, got $got: $(head -c 160 "$T/err"))"; }
main() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' "$SID" "$1" "$2"; }
agent() { main Agent "{\"description\":\"x\",$1}"; }

echo "== model guard"
expect 0 "helper-planner allowed" "$(agent '"subagent_type":"helper-planner","prompt":"plan"')"
expect 0 "helper-reviewer allowed" "$(agent '"subagent_type":"helper-reviewer","prompt":"review"')"
expect 0 "planner with model opus allowed" "$(agent '"subagent_type":"helper-planner","model":"opus","prompt":"plan"')"
expect 2 "helper-careful retired" "$(agent '"subagent_type":"helper-careful","prompt":"x"')"
grep -q "retired" "$T/err" && ok || bad "retired message"
expect 2 "helper-heavy retired" "$(agent '"subagent_type":"helper-heavy","prompt":"x"')"
expect 2 "model opus general-purpose refused" "$(agent '"subagent_type":"general-purpose","model":"opus","prompt":"x"')"
expect 2 "model opus no type refused" "$(agent '"model":"opus","prompt":"x"')"
grep -q "only for helper-planner" "$T/err" && ok || bad "opus message"
expect 2 "Plan helper refused" "$(agent '"subagent_type":"Plan","prompt":"x"')"
grep -q "use helper-planner" "$T/err" && ok || bad "Plan message"
expect 0 "helper-light allowed" "$(agent '"subagent_type":"helper-light","prompt":"rename x"')"
expect 0 "helper-medium allowed" "$(agent '"subagent_type":"helper-medium","prompt":"build x"')"
expect 0 "helper-scout allowed" "$(agent '"subagent_type":"helper-scout","prompt":"look"')"
expect 0 "helper-check allowed" "$(agent '"subagent_type":"helper-check","prompt":"look"')"
expect 2 "helper-builder without REPO refused" "$(agent '"subagent_type":"helper-builder","prompt":"build"')"
grep -q "REPO:" "$T/err" && ok || bad "REPO message"
expect 0 "helper-builder with REPO allowed" "$(agent '"subagent_type":"helper-builder","prompt":"REPO: /x/y\\nbuild"')"
expect 0 "no model, no type allowed" "$(agent '"prompt":"x"')"
expect 0 "model opusplan is not Opus" "$(agent '"subagent_type":"general-purpose","model":"opusplan","prompt":"x"')"
expect 0 "model sonnet allowed" "$(agent '"subagent_type":"general-purpose","model":"sonnet","prompt":"x"')"
expect 2 "Fable helper type blocked" "$(agent '"subagent_type":"helper-fable","prompt":"x"')"
expect 2 "Fable model blocked" "$(agent '"subagent_type":"general-purpose","model":"fable","prompt":"x"')"
expect 2 "Opus side chat refused" "$(main mcp__ccd_session__start_session '{"initiation":"user_asked","model":"claude-opus-5-5","prompt":"x"}')"
expect 0 "Sonnet side chat allowed" "$(main mcp__ccd_session__start_session '{"initiation":"user_asked","model":"claude-sonnet-5-5","prompt":"x"}')"
expect 0 "start proposed card allowed" "$(main mcp__ccd_session__start_session '{"proposal_id":"task_1"}')"
expect 2 "start_session Fable blocked" "$(main mcp__ccd_session__start_session '{"initiation":"user_asked","model":"claude-fable-5-2","prompt":"x"}')"
expect 2 "set_session_model opus refused" "$(main mcp__ccd_session_mgmt__set_session_model '{"model":"claude-opus-5-5"}')"
expect 0 "set_session_model sonnet ok" "$(main mcp__ccd_session_mgmt__set_session_model '{"model":"claude-sonnet-5-5"}')"
expect 0 "other tools ignored" "$(main Bash '{"command":"ls"}')"
expect 2 "set_session_effort high refused" "$(main mcp__ccd_session_mgmt__set_session_effort '{"effort":"high"}')"
expect 2 "set_session_effort max refused" "$(main mcp__ccd_session_mgmt__set_session_effort '{"effort":"max"}')"
grep -q "no OK for it" "$T/err" && ok || bad "effort message"
expect 0 "set_session_effort medium ok" "$(main mcp__ccd_session_mgmt__set_session_effort '{"effort":"medium"}')"
expect 2 "start_session xhigh refused" "$(main mcp__ccd_session__start_session '{"initiation":"user_asked","model":"claude-sonnet-5-5","effort":"xhigh","prompt":"x"}')"
expect 2 "helper with effort high refused" "$(agent '"subagent_type":"helper-medium","effort":"high","prompt":"x"')"
expect 0 "hard work on a Sonnet builder allowed" "$(agent '"subagent_type":"helper-builder","prompt":"REPO: /x\\nunknown cause, messy code"')"
# a leftover permission file changes nothing
: > "$CLAUDE_GUARD_STATE/opus-ok-$SID"
expect 2 "leftover marker does not open Opus" "$(agent '"subagent_type":"general-purpose","model":"opus","prompt":"x"')"

rm -rf "$T"
echo "model-guard tests: $pass passed, $fail failed"; [ "$fail" = 0 ]
