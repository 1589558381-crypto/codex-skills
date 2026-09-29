# codex-skills

Reusable Codex skills for project-local use.

## Layout

```text
codex-skills/
├─ skills/
│  └─ hello-codex/
│     └─ SKILL.md
└─ scripts/
   ├─ install-skill.ps1
   └─ install-all.ps1
```

Each skill lives in its own folder under `skills/` and contains a required `SKILL.md`.

## Install into one project only

Run these commands from the root of the project where you want Codex to use the skill.

Install one skill:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/1589558381-crypto/codex-skills/main/scripts/install-skill.ps1 -OutFile .\install-skill.ps1
.\install-skill.ps1 -Name hello-codex
Remove-Item .\install-skill.ps1
```

The skill is copied to:

```text
.agents/skills/<skill-name>/
```

Nothing is written to your global Codex configuration.

Install all skills:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/1589558381-crypto/codex-skills/main/scripts/install-all.ps1 -OutFile .\install-all.ps1
.\install-all.ps1
Remove-Item .\install-all.ps1
```

## Add a new skill

Create `skills/<skill-name>/SKILL.md`.

Minimal example:

```markdown
---
name: my-skill
description: Explain what this skill does and when Codex should use it.
---

Put the reusable workflow instructions here.
```
