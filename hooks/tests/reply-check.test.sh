#!/bin/bash
# Feeds sample Stop / PostToolUse inputs to reply-check.sh. Portable bash. Run: bash hooks/tests/reply-check.test.sh
H=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d 2>/dev/null || mktemp -d -t replytests)
export CLAUDE_GUARD_STATE="$T/state"; mkdir -p "$CLAUDE_GUARD_STATE"; unset CLAUDE_PROJECT_DIR
pass=0 fail=0
ok() { pass=$((pass+1)); }; bad() { fail=$((fail+1)); echo "FAIL: $1"; }
S=reply-sess-1
# stop <message-json-escaped> [stop_hook_active] [session]
stop() { printf '{"session_id":"%s","hook_event_name":"Stop","stop_hook_active":%s,"last_assistant_message":"%s"}' "${3:-$S}" "${2:-false}" "$1" | bash "$H/reply-check.sh"; }
# edit <file_path-json-escaped> [session]
edit() { printf '{"session_id":"%s","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a"},"tool_response":{}}' "${2:-$S}" "$1" | bash "$H/reply-check.sh"; }
silent() { local o; o=$(eval "$2"); [ -z "$o" ] && ok || bad "$1 (expected silence, got ${o:0:140})"; }
blocked() { local o; o=$(eval "$2"); case $o in '{"decision":"block"'*) ok;; *) bad "$1 (expected block, got ${o:0:100})"; return;; esac
  if [ -n "$3" ]; then case $o in *"$3"*) ok;; *) bad "$1 (reason lacks '$3': ${o:0:200})";; esac; fi; }

silent  "clean short reply passes" 'stop "All good. The report is ready."'
blocked "jargon blocked" 'stop "I used a subagent and a worktree for this."' "subagent"
blocked "MCP / context window blocked" 'stop "The MCP server hit the context window."' "context window"
silent  "jargon inside code block passes" 'stop "Run this:\n\`\`\`\nclaude subagent hooks worktree\n\`\`\`\nIt starts it."'
silent  "jargon in backticks passes" 'stop "Edit the \`hooks\` file."'
silent  "jargon in path and URL passes" 'stop "See ~/Projects/.claude/hooks/x.sh and https://example.com/hooks now."'
blocked "old name house rules blocked" 'stop "Updated the house rules."' "house rules"
silent  "shared rules fine" 'stop "Updated the shared rules."'
L=""; for i in $(seq 1 18); do L="$L line $i here.\n"; done
blocked "long reply blocked" 'stop "$L"' "Too long"
LC=""; for i in $(seq 1 30); do LC="${LC}x\n"; done
silent  "long code block only passes" 'stop "Here:\n\`\`\`\n${LC}\`\`\`\nDone."'
edit "/Users/r/Projects/admin/script.js"
blocked "code changed, no Review line blocked" 'stop "Fixed it."' "Review:"
edit "/Users/r/Projects/admin/script.js"
silent  "code changed, Review line passes" 'stop "Fixed it.\nReview: checked the build."'
edit "/Users/r/Projects/admin/script.js"
silent  "code changed, bold Review line passes" 'stop "Fixed it.\n**Review:** checked."'
silent  "record cleared after Stop" 'stop "Fixed it."'
edit "/Users/r/Projects/admin/handovers/task.md"
edit "C:\\\\Users\\\\r\\\\Projects\\\\ACTIVE.md"
edit "/Users/r/.claude/projects/p/memory/x.md"
silent  "only handover/notes changed passes" 'stop "Saved."'
edit "/Users/r/Projects/admin/script.js"
silent  "stop_hook_active passes" 'stop "Fixed it." true'
silent  "helper event ignored" 'printf "%s" "{\"session_id\":\"h1\",\"agent_id\":\"a1\",\"hook_event_name\":\"Stop\",\"last_assistant_message\":\"subagent hooks worktree\"}" | bash "$H/reply-check.sh"'
# git: says done but not saved
R="$T/repo"; mkdir -p "$R"; git -C "$R" init -q 2>/dev/null; git -C "$R" config user.email t@t; git -C "$R" config user.name t
echo 1 > "$R/a.txt"; git -C "$R" add a.txt; git -C "$R" commit -qm one
echo 2 > "$R/a.txt"
edit "$R/a.txt" gs1
blocked "done with uncommitted file blocked" 'stop "All done.\nReview: ok." false gs1' "Commit and push"
git -C "$R" commit -qam two
edit "$R/a.txt" gs2
silent  "done, committed, no upstream passes" 'stop "All done.\nReview: ok." false gs2'
B="$T/bare.git"; git init -q --bare "$B" 2>/dev/null; git -C "$R" remote add origin "$B"; git -C "$R" push -q -u origin HEAD 2>/dev/null
echo 3 > "$R/a.txt"; git -C "$R" commit -qam three
edit "$R/a.txt" gs3
blocked "done with unpushed commit blocked" 'stop "Finished and pushed.\nReview: ok." false gs3' "not pushed"
git -C "$R" push -q 2>/dev/null
edit "$R/a.txt" gs4
silent  "done, committed and pushed passes" 'stop "All done.\nReview: ok." false gs4'
echo 4 > "$R/a.txt"; edit "$R/a.txt" gs5
silent  "unsaved but reply not a finish passes" 'stop "Working on it.\nReview: ok." false gs5'
echo "passed: $pass  failed: $fail"; rm -rf "$T"; [ "$fail" = 0 ]
