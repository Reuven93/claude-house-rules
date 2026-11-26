#!/bin/bash
# Tests for model-guard.sh and the "ok opus" marker in prompt-gate.sh. Portable bash, no jq/python. Run: bash hooks/tests/model-guard.test.sh
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
prompt() { printf '{"session_id":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$SID" "$1" | bash "$H/prompt-gate.sh"; }
has() { [ -f "$CLAUDE_GUARD_STATE/$1-$SID" ]; }
noOK() { rm -f "$CLAUDE_GUARD_STATE/opus-ok-$SID"; }
main() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' "$SID" "$1" "$2"; }
agent() { main Agent "{\"description\":\"x\",$1}"; }
S=model-guard.sh

for p in "ok opus" "Yes, use Opus for this" "go ahead with the stronger model" "OK Opus"; do
  prompt "$p"; has opus-ok && ok || bad "approval wording: '$p'"
done
for p in "ok opus, not sonnet" "use opus, not haiku"; do
  noOK; prompt "$p"; has opus-ok && ok || bad "approval wording: '$p'"
done
for p in "what does opus cost?" "don't use opus" "no opus, use sonnet" "carry on"; do
  noOK; prompt "$p"; has opus-ok && bad "not approval: '$p'" || ok
done
prompt "ok opus"; prompt "carry on"; has opus-ok && ok || bad "OK survives the next message"
prompt "don't use opus any more"; has opus-ok && bad "\"don't use opus\" takes the OK back" || ok
noOK; prompt "carry on"
echo "== model guard"
noOK
expect 2 "helper-careful without OK blocked" "$(agent '"subagent_type":"helper-careful","prompt":"review"')"
expect 2 "helper-heavy without OK blocked" "$(agent '"subagent_type":"helper-heavy","prompt":"x"')"
expect 2 "model opus without OK blocked" "$(agent '"subagent_type":"general-purpose","model":"opus","prompt":"x"')"
expect 2 "start_session opus without OK blocked" "$(main mcp__ccd_session__start_session '{"initiation":"user_asked","model":"claude-opus-5-5","prompt":"x"}')"
expect 0 "helper-light allowed" "$(agent '"subagent_type":"helper-light","prompt":"rename x"')"
expect 0 "helper-medium allowed" "$(agent '"subagent_type":"helper-medium","prompt":"build x"')"
expect 0 "helper-scout allowed" "$(agent '"subagent_type":"helper-scout","prompt":"look"')"
expect 0 "helper-check allowed" "$(agent '"subagent_type":"helper-check","prompt":"look"')"
expect 0 "no model, no type allowed" "$(agent '"prompt":"x"')"
expect 0 "model opusplan is not Opus" "$(agent '"subagent_type":"general-purpose","model":"opusplan","prompt":"x"}')"
expect 0 "start_session sonnet allowed" "$(main mcp__ccd_session__start_session '{"initiation":"user_asked","model":"claude-sonnet-5-5","prompt":"x"}')"
expect 0 "start proposed card allowed" "$(main mcp__ccd_session__start_session '{"proposal_id":"task_1"}')"
expect 2 "Fable helper type blocked" "$(agent '"subagent_type":"helper-fable","prompt":"x"')"
expect 2 "Fable model blocked" "$(agent '"subagent_type":"general-purpose","model":"fable","prompt":"x"')"
expect 2 "start_session Fable blocked" "$(main mcp__ccd_session__start_session '{"initiation":"user_asked","model":"claude-fable-5-2","prompt":"x"}')"
expect 0 "other tools ignored" "$(main Bash '{"command":"ls"}')"
prompt "ok opus"
expect 0 "helper-careful with OK allowed" "$(agent '"subagent_type":"helper-careful","prompt":"review"')"
expect 0 "model opus with OK allowed" "$(agent '"subagent_type":"general-purpose","model":"opus","prompt":"x"')"
expect 0 "start_session opus with OK allowed" "$(main mcp__ccd_session__start_session '{"initiation":"user_asked","model":"claude-opus-5-5","prompt":"x"}')"
expect 2 "Fable blocked even with OK" "$(agent '"subagent_type":"general-purpose","model":"fable","prompt":"x"')"
SID=other-session
expect 2 "OK does not carry to another chat" "$(agent '"subagent_type":"helper-careful","prompt":"x"')"

rm -rf "$T"
echo "model-guard tests: $pass passed, $fail failed"
[ "$fail" = 0 ]
