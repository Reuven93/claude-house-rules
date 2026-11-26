# Install or update the house rules (instructions for Claude Code)

Follow these steps when she says "install my house rules" or "update my house rules". She is on Windows. `~` means `C:\Users\<name>`. Use PowerShell for commands unless she says Git Bash. Speak plainly (Background, Issue, Resolution).

1. **Get the latest kit.** If `~\claude-house-rules` exists, run `git -C ~/claude-house-rules pull`. If not, run `git clone https://github.com/Reuven93/claude-house-rules ~/claude-house-rules`. If git is missing, tell her to install Git for Windows (https://git-scm.com/download/win) and stop. If it asks her to sign in, tell her to accept the GitHub invite and sign in, then stop.
2. **Compare** each kit file with the installed one (a missing file counts as "new"):

   | Kit file | Installed at |
   |---|---|
   | `CLAUDE.md` | `~\.claude\CLAUDE.md` |
   | `skills\handover\SKILL.md`, `skills\handover\TEMPLATE.md` | `~\.claude\skills\handover\` |
   | `skills\rules-check\SKILL.md` | `~\.claude\skills\rules-check\` |
   | `agents\helper-*.md` (6 files) | `~\.claude\agents\` |
   | `settings.json` | `~\.claude\settings.json` (merge, step 5) |

   Do not touch other files in `~\.claude`, and do not delete anything there.
3. **Show her a short plain list** of what will change: for each file "new", "changed" (one line on what differs, e.g. the new house-rules version) or "same". If nothing differs, say "You are up to date" and stop. If her installed `CLAUDE.md` has rules that are not in the kit, mention them in one line, because replacing the file removes them.
4. **Wait for her OK.** Do nothing before it.
5. **Apply.** For each new or changed file: if an installed file exists, copy it to `<name>.bak` in the same folder (overwrite an older `.bak`); create folders if needed; then copy the kit file over it. For `settings.json`: read her installed file (create `{}` if missing), set only `"model": "opusplan"` and the two `env` keys (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`) from the kit's `settings.json`, keep every other key (including other `env` keys and any `hooks`) exactly as is, and back up first as `settings.json.bak`. Valid JSON only.
6. **Check:** list the installed files, confirm `settings.json` still parses, and report in 1-3 lines what was installed and the version line from `CLAUDE.md`.
7. **Tell her:** "Start a new chat so the new rules load." Then stop.
