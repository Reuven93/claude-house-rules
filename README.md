# Your Claude Code rules

This is a small kit that sets up Claude Code on your Windows PC the way it works best for building apps and claude.ai artifacts: it makes a plan before it builds, uses helpers working in parallel, checks its own work with an independent review, keeps handover notes so a new chat can carry on, and talks to you in short, plain sentences. It is a set of rules, two skills, six helper types and a few settings.

## One-time setup
1. Open Claude Code in any folder and paste this message (no GitHub account or sign-in needed):

```text
My husband set up rules for how you should work for me. Clone https://github.com/Reuven93/claude-house-rules into a folder called claude-house-rules in my home folder, follow its INSTALL.md, and set everything up for me. Ask me only for the yes/no permissions.
```

2. Claude shows you a short list of what it will change and asks permission several times to copy files into `.claude`. Say Yes. It backs up anything it replaces (in `.claude\house-rules-backup\`).
3. Start a new chat. The rules are now active.

## Updating later
Open Claude Code and say:

```text
update my rules
```

(Saying "update my house rules" also works.) Claude pulls the newest version, shows you what changes, waits for your OK, then installs it. Start a new chat afterwards.

## Your own rules
Add your own rules to `~/.claude/CLAUDE.md` (in `C:\Users\<your name>\.claude\`) under the heading "My own rules". Updates never touch that section; they only replace the kit's `shared-rules.md`.

## What it changes in your settings
It sets the model to `opusplan` (Opus plans, Sonnet builds), limits how many helpers run at once, and makes helpers default to Sonnet. Everything else in your settings stays as it is.

## "Follow the rules"
If Claude drifts (long answers, no plan, jumping straight into building), say **"follow the rules"**. It re-reads your rules, checks what it has done so far, tells you in 1-3 lines what slipped, fixes it and carries on.

## Opening Claude Code in a project folder
- Desktop app: pick the project's folder when you start a chat.
- Terminal: `cd` into the folder, then run `claude`.

Start each project's chat in that project's folder so its own notes are found.

## Tips
- Say "full run" when you want the complete test suite instead of just what changed.

## Troubleshooting
If Claude Code says it can't find Git Bash, paste this into PowerShell, then restart Claude Code:

```text
setx CLAUDE_CODE_GIT_BASH_PATH "C:\Program Files\Git\bin\bash.exe"
```
