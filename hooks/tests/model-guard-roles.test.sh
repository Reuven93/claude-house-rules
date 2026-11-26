#!/bin/bash
# Tests for the role rules in model-guard.sh (Opus only for helper-planner / helper-reviewer). Run: bash .claude/hooks/tests/model-guard-roles.test.sh
H=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d 2>/dev/null || mktemp -d -t mgroles)
export CLAUDE_GUARD_STATE="$T/state" TMPDIR="$T/tmp"; mkdir -p "$CLAUDE_GUARD_STATE" "$TMPDIR"
unset CLAUDE_PROJECT_DIR
pass=0 fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
expect() {
  local want=$1 label=$2 js=$3 got
  printf '%s' "$js" | bash "$H/model-guard.sh" >/dev/null 2>"$T/err"; got=$?
  [ "$got" = "$want" ] && ok || bad "$label (want exit $want, got $got: $(head -c 200 "$T/err"))"
}
S=s1
agent() { printf '{"session_id":"%s","tool_name":"Agent","tool_input":{"description":"x",%s}}' "$S" "$1"; }
# a leftover opus-ok marker must NOT matter; test both with and without it
for okmark in no yes; do
  rm -f "$CLAUDE_GUARD_STATE"/*; [ $okmark = yes ] && : > "$CLAUDE_GUARD_STATE/opus-ok-$S"
  L="[opus-ok=$okmark]"
  expect 0 "$L planner with TIER 3" "$(agent '"subagent_type":"helper-planner","prompt":"TIER: 3\\nplan it"')"
  expect 0 "$L planner TIER 4" "$(agent '"subagent_type":"helper-planner","prompt":"TIER: 4\\nplan it"')"
  expect 0 "$L reviewer with TIER 3" "$(agent '"subagent_type":"helper-reviewer","prompt":"TIER: 3\\nreview"')"
  expect 0 "$L planner model opus TIER 3" "$(agent '"subagent_type":"helper-planner","model":"opus","prompt":"TIER: 3\\nplan"')"
  expect 2 "$L planner without TIER" "$(agent '"subagent_type":"helper-planner","prompt":"plan it"')"
  expect 2 "$L planner TIER 2" "$(agent '"subagent_type":"helper-planner","prompt":"TIER: 2\\nplan"')"
  expect 2 "$L reviewer without TIER" "$(agent '"subagent_type":"helper-reviewer","prompt":"review"')"
  expect 2 "$L helper-careful refused" "$(agent '"subagent_type":"helper-careful","prompt":"TIER: 3\\nx"')"
  grep -q "Opus is only for helper-planner and helper-reviewer" "$T/err" && ok || bad "$L careful message"
  expect 2 "$L helper-heavy refused" "$(agent '"subagent_type":"helper-heavy","prompt":"TIER: 4\\nx"')"
  expect 2 "$L model opus general-purpose refused" "$(agent '"subagent_type":"general-purpose","model":"opus","prompt":"TIER: 3\\nx"')"
  expect 2 "$L model opus no type refused" "$(agent '"model":"opus","prompt":"TIER: 3\\nx"')"
  expect 2 "$L Plan helper refused" "$(agent '"subagent_type":"Plan","prompt":"x"')"
  grep -q "use helper-planner" "$T/err" && ok || bad "$L Plan message"
  expect 2 "$L helper-builder without REPO" "$(agent '"subagent_type":"helper-builder","model":"sonnet","prompt":"TIER: 2\\nbuild"')"
  grep -q "REPO:" "$T/err" && ok || bad "$L REPO message"
  expect 0 "$L helper-builder with REPO" "$(agent '"subagent_type":"helper-builder","model":"sonnet","prompt":"REPO: /x/y\\nTIER: 2\\nbuild"')"
  expect 0 "$L helper-medium sonnet" "$(agent '"subagent_type":"helper-medium","prompt":"TIER: 2\\nx"')"
  expect 0 "$L Explore still allowed" "$(agent '"subagent_type":"Explore","prompt":"x"')"
  expect 2 "$L Opus side chat refused" "$(printf '{"session_id":"%s","tool_name":"mcp__ccd_session__start_session","tool_input":{"model":"claude-opus-5","initiation":"own_initiative","prompt":"x"}}' "$S")"
  expect 0 "$L Sonnet side chat ok" "$(printf '{"session_id":"%s","tool_name":"mcp__ccd_session__start_session","tool_input":{"model":"claude-sonnet-5-5","effort":"medium","initiation":"own_initiative","prompt":"x"}}' "$S")"
  expect 2 "$L set_session_model opus refused" "$(printf '{"session_id":"%s","tool_name":"mcp__ccd_session_mgmt__set_session_model","tool_input":{"model":"claude-opus-5"}}' "$S")"
  expect 0 "$L set_session_model opusplan ok" "$(printf '{"session_id":"%s","tool_name":"mcp__ccd_session_mgmt__set_session_model","tool_input":{"model":"opusplan"}}' "$S")"
  expect 0 "$L TIER 4 Sonnet builder allowed" "$(agent '"subagent_type":"helper-builder","model":"sonnet","prompt":"REPO: /x/y\\nTIER: 4\\nfix"')"
  expect 2 "$L set_session_effort high refused (no OK path)" "$(printf '{"session_id":"%s","tool_name":"mcp__ccd_session_mgmt__set_session_effort","tool_input":{"effort":"high"}}' "$S")"
  expect 0 "$L set_session_effort low ok" "$(printf '{"session_id":"%s","tool_name":"mcp__ccd_session_mgmt__set_session_effort","tool_input":{"effort":"low"}}' "$S")"
  expect 2 "$L fable still refused" "$(agent '"subagent_type":"helper-scout","model":"fable","prompt":"x"')"
  expect 2 "$L general-purpose sonnet refused" "$(agent '"subagent_type":"general-purpose","model":"sonnet","prompt":"x"')"
  grep -q "use a helper-\* type" "$T/err" && ok || bad "$L savvy type message"
  expect 2 "$L no type, model sonnet refused" "$(agent '"model":"sonnet","prompt":"x"')"
  expect 2 "$L no type no model refused" "$(agent '"prompt":"x"')"
  expect 0 "$L claude-code-guide allowed" "$(agent '"subagent_type":"claude-code-guide","prompt":"x"')"
  expect 0 "$L web-fetch allowed" "$(agent '"subagent_type":"web-fetch","prompt":"x"')"
done
# session-model tool logging: one line per tool name, naming it
rm -f "$CLAUDE_GUARD_STATE"/*
for i in 1 2; do printf '{"session_id":"s1","tool_name":"mcp__ccd_session_mgmt__set_session_model","tool_input":{"model":"opusplan"}}' | bash "$H/model-guard.sh" >/dev/null 2>&1; done
printf '{"session_id":"s1","tool_name":"mcp__ccd_session_mgmt__set_session_effort","tool_input":{"effort":"low"}}' | bash "$H/model-guard.sh" >/dev/null 2>&1
[ "$(grep -c 'tool=mcp__ccd_session_mgmt__set_session_model' "$CLAUDE_GUARD_STATE/model-guard.log")" = 1 ] && ok || bad "log set_session_model once"
grep -q 'tool=mcp__ccd_session_mgmt__set_session_effort' "$CLAUDE_GUARD_STATE/model-guard.log" && ok || bad "log set_session_effort"
# prompt-gate markers
pg() { printf '{"session_id":"s9","prompt":"%s"}' "$1" | bash "$H/prompt-gate.sh" >/dev/null 2>&1; }
pg "please role guard off now"; [ -f "$CLAUDE_GUARD_STATE/role-off-s9" ] && ok || bad "role-off marker"
pg "update my rules"; [ -f "$CLAUDE_GUARD_STATE/rules-update-s9" ] && ok || bad "rules-update marker (update)"
rm -f "$CLAUDE_GUARD_STATE/rules-update-s9"; pg "Install my rules please"; [ -f "$CLAUDE_GUARD_STATE/rules-update-s9" ] && ok || bad "rules-update marker (install)"
pg "hello there"; [ -f "$CLAUDE_GUARD_STATE/role-off-s8" ] && bad "no stray marker" || ok
rm -rf "$T"
echo "model-guard-roles: $pass passed, $fail failed"; [ "$fail" = 0 ]
