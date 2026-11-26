# Install or update the house rules (instructions for Claude Code)

Follow these steps when she says "install my house rules" or "update my house rules". She is on Windows. `~` means `C:\Users\<name>`. Speak plainly (Background, Issue, Resolution).

**Tell her up front:** "I will ask your permission several times to copy files into your `.claude` folder. Please say Yes each time."

1. **Get the latest kit.** Detect which shell you have. In PowerShell: if `~\claude-house-rules` exists run `git -C "$HOME\claude-house-rules" pull`, otherwise run `git clone https://github.com/Reuven93/claude-house-rules "$HOME\claude-house-rules"`. In Git Bash: the same commands with `~/claude-house-rules`. If the pull fails because files in that folder were edited, show her which files, keep her edits out of the way with `git -C <folder> stash` (tell her they are saved there), and pull again. If git is missing, tell her to install Git for Windows (https://git-scm.com/download/win) and stop. If the download waits on a GitHub sign-in (or fails asking for one), stop and give her the clone command to paste into PowerShell herself (a sign-in window opens in her browser; she signs in with the account that got the invite), then continue once it has finished:

   ```text
   git clone https://github.com/Reuven93/claude-house-rules "$HOME\claude-house-rules"
   ```
2. **Compare** each kit file with the installed one (a missing file counts as "new"):

   | Kit file | Installed at |
   |---|---|
   | `house-rules.md` | `~\.claude\house-rules.md` (replaced on update, with backup) |
   | `skills\handover\SKILL.md`, `skills\handover\TEMPLATE.md` | `~\.claude\skills\handover\` |
   | `skills\rules-check\SKILL.md` | `~\.claude\skills\rules-check\` |
   | `agents\helper-*.md` (6 files) | `~\.claude\agents\` |
   | `settings.json` | `~\.claude\settings.json` (merge, step 5) |

   `~\.claude\CLAUDE.md` is HERS and is not a kit file: it is handled in step 5. Do not touch other files in `~\.claude`, and do not delete anything there.
3. **Show her a short plain list** of what will change: for each file "new", "changed" (one line on what differs, e.g. the new house-rules version) or "same". Also say what will happen to her `CLAUDE.md` (see step 5). If nothing differs and her `CLAUDE.md` already has the `@house-rules.md` line, say "You are up to date" and stop.
4. **Wait for her OK.** Do nothing before it.
5. **Apply.**
   - **Kit files:** for each new or changed file, if an installed file exists, first copy it into `~\.claude\house-rules-backup\<date-time>\`, keeping its sub-folder (e.g. `agents\helper-light.md`). Never leave backups inside `agents\` or `skills\`: Claude Code may load them as extra helpers or skills. Create folders if needed; then copy the kit file over it.
   - **Her `CLAUDE.md`:** it must contain the line `@house-rules.md` at the very top and a `## My own rules` section. If she has no `CLAUDE.md`, create one with `@house-rules.md` followed by the content of the kit's `my-rules-template.md`. **One-time move (house rules 26/11/2026b):** the Windows and helper-name rules left the shared `house-rules.md`; if her `## My own rules` section has no `### My machine (Windows PC)` heading, append the `###` blocks from `my-rules-template.md` to the end of that section (backup first, show her the addition, change nothing else she wrote). First install with an existing `CLAUDE.md`: show it to her, and with her OK move its content under `## My own rules` (copy it into the same backup folder first). On later updates only add the `@house-rules.md` line if it is missing; never touch the `## My own rules` section or anything she wrote.
   - **`settings.json`:** read her installed file (create `{}` if missing), set only `"model": "opusplan"` and the three `env` keys (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, `CLAUDE_CODE_SUBAGENT_MODEL` = `"sonnet"`, which makes helpers that don't name a model run on Sonnet, not Opus; helpers that name their own model keep it) from the kit's `settings.json`, keep every other key (including other `env` keys and any `hooks`) exactly as is, and back it up into the same backup folder first. Valid JSON only.
6. **Check:** run `claude --version`; the helper limit setting needs 2.1.217 or later, so if it is older tell her to update Claude Code. List the installed files, confirm `settings.json` still parses, and report in 1-3 lines what was installed and the version line from `house-rules.md`.
7. **Tell her:** "Start a new chat so the new rules load." Then stop.
