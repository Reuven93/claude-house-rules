# My Claude house rules

This is a small kit that sets up Claude Code on your Windows PC the way it works best for building apps and claude.ai artifacts: it makes a plan before it builds, uses helpers working in parallel, checks its own work with an independent review, keeps handover notes so a new chat can carry on, and talks to you in short, plain sentences. It is a kit of rules, two skills, six helper types and a few settings.

## One-time setup
1. Accept the GitHub invitation to the private `claude-house-rules` repo (check your email).
2. Install Git for Windows if you don't have it: https://git-scm.com/download/win (accept the defaults), then sign in to GitHub when asked.
3. Open Claude Code and paste this one line:

```text
Clone https://github.com/Reuven93/claude-house-rules into a folder called claude-house-rules in my home folder, then follow its INSTALL.md
```

4. Claude shows you a short list of what it will change. Say OK. It backs up anything it replaces (as `.bak` files).
5. Start a new chat. The rules are now active.

## Updating later
Open Claude Code and say:

```text
update my house rules
```

Claude pulls the newest version, shows you what changes, waits for your OK, then installs it. Start a new chat afterwards.

## "Follow the rules"
If Claude drifts (long answers, no plan, jumping straight into building), say **"follow the rules"**. It re-reads your rules, checks what it has done so far, tells you in 1-3 lines what slipped, fixes it and carries on.

## Tips
- Start each project's chat in that project's folder so its own notes are found.
- Say "full run" when you want the complete test suite instead of just what changed.
- Nothing here changes your other settings: only the model and two helper limits are added to `settings.json`.
