# codex-skills

A project-local Codex skill library and unified PowerShell skill manager.

The repository tracks 17 external skill sources and exposes 1,033 normalized skills through one command. Skills are installed only into the current project's `.agents/skills/` directory. Nothing is installed into the global Codex configuration.

## Quick start for PowerShell

Open PowerShell in the root of the project where you want to use Codex skills.

Download the unified manager:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/1589558381-crypto/codex-skills/main/skill.ps1 -OutFile .\skill.ps1
Unblock-File .\skill.ps1
```

See available source libraries:

```powershell
.\skill.ps1 sources
```

Search the full catalog:

```powershell
.\skill.ps1 search writing
.\skill.ps1 search citation
.\skill.ps1 search slides
```

Install one skill:

```powershell
.\skill.ps1 install nature-writing
```

The result is always project-local:

```text
your-project/
├─ skill.ps1
└─ .agents/
   └─ skills/
      ├─ nature-shared/
      └─ nature-writing/
```

For Nature skills, required `nature-shared` support is installed automatically.

## Common commands

```powershell
# Show all source repositories
.\skill.ps1 sources

# Show all skills
.\skill.ps1 list

# Show skills from one source
.\skill.ps1 list nature
.\skill.ps1 list anthropic

# Search by keyword
.\skill.ps1 search literature
.\skill.ps1 search reviewer

# Show where a skill comes from
.\skill.ps1 info nature-writing

# Install one skill
.\skill.ps1 install nature-writing

# Install a skill from an explicit source
.\skill.ps1 install anthropic/frontend-design
.\skill.ps1 install kdense/literature-review

# Install every normalized skill from one source
.\skill.ps1 install-source nature

# Replace an already installed skill with the pinned repository version
.\skill.ps1 install nature-writing -Force

# Remove a project-local skill
.\skill.ps1 remove nature-writing
```

## Duplicate skill names

Most skill names are unique. When the same name exists in multiple repositories, the manager refuses to guess and asks for a qualified selector.

For example:

```powershell
.\skill.ps1 install anthropic/pdf
.\skill.ps1 install kdense/pdf
```

Qualified selectors use:

```text
<source-alias>/<skill-name>
```

## Source aliases

| Alias | Repository |
|---|---|
| `kdense` | K-Dense-AI/scientific-agent-skills |
| `aipoch` | aipoch/medical-research-skills |
| `nature` | Yuan1z0825/nature-skills |
| `academic` | Imbad0202/academic-research-skills-codex |
| `autoresearch` | leo-lilinxiao/codex-autoresearch |
| `zlanqing` | zLanqing/codex-claude-academic-skills |
| `aris` | wanshuiyin/Auto-claude-code-research-in-sleep |
| `orchestra` | Orchestra-Research/AI-Research-SKILLs |
| `social` | fakerqwq/social-science-paper-writing-skill |
| `digest` | xuezheng627/daily-literature-digest-skill |
| `vault` | xuezheng627/research-radar-paper-vault |
| `slides` | zarazhangrui/frontend-slides |
| `impeccable` | pbakaus/impeccable |
| `uiux` | nextlevelbuilder/ui-ux-pro-max-skill |
| `vercel` | vercel-labs/agent-skills |
| `anthropic` | anthropics/skills |
| `cnki` | cfh-7598/cnki-codex-skills |

## CNKI literature skills

The `cnki` source contains 15 Codex skills for CNKI literature and journal workflows. Install the full suite (including the `cnki-codex` router) into the current project's `.agents/skills/` directory:

```powershell
.\skill.ps1 install cnki-codex
# or: .\skill.ps1 install-source cnki
```

The installer automatically copies the required shared Python runtime to `.agents/skills/_shared/cnki/`. Install the Python dependency separately:

```powershell
python -m pip install "playwright>=1.51,<2"
```

To run the search wrapper from the project root:

```powershell
python .agents/skills/cnki-search-codex/scripts/run.py --query "人工智能"
```

The browser workflow requires Chrome started with remote debugging (`--remote-debugging-port=9222`) and any required CNKI login completed manually. It does not bypass account permissions or captchas. Zotero is only required for its export mode.

## AIPOCH medical research skills

The `aipoch` source contains **605 indexed skills** across medical research, evidence appraisal, protocol design, data analysis, and academic writing. All skills are tracked as a pinned Git submodule; the existing `kdense` scientific skills source remains available unchanged.

```powershell
# List medical research skills
.\skill.ps1 list aipoch

# Find a medical research skill
.\skill.ps1 search medical

# Install one medical skill into this project
.\skill.ps1 install aipoch/medical-research-gap-finder

# Install all AIPOCH skills into this project (large download)
.\skill.ps1 install-source aipoch

# Install an existing K-Dense skill into this project
.\skill.ps1 install kdense/literature-review
```

The installer copies only selected skill directories into the project's `.agents/skills/` and uses `git sparse-checkout --stdin` for large batches, including paths containing spaces. The source repository itself is tracked under `sources/medical-research-skills/`. Source-qualified selectors (`aipoch/<skill>`, `kdense/<skill>`) resolve overlapping skill names. One AIPOCH cover-letter skill has a unique installed name (`scientific-cover-letter-drafter`) to distinguish two separate source entries.

Third-party skills may require additional local software, API credentials, or datasets. Review their instructions and code before executing them; adding them to this catalog does not install dependencies or grant external access.

## Repository layout

```text
codex-skills/
├─ skill.ps1
├─ registry/
│  └─ skills.json
├─ skills/
│  └─ hello-codex/
├─ sources/
│  ├─ nature-skills/
│  ├─ scientific-agent-skills/
│  └─ ...
├─ scripts/
│  ├─ install-skill.ps1
│  ├─ install-all.ps1
│  ├─ install-nature-skill.ps1
│  └─ install-nature-all.ps1
└─ .gitmodules
```

The scripts under `scripts/` are retained for compatibility. For new projects, use the root `skill.ps1` manager.

## Reproducibility

The registry pins each external repository to a specific Git commit. Installing a skill therefore uses the version recorded by this repository instead of silently switching to whatever happens to be latest upstream.

The installed skill contains a `.codex-skill-source.json` file recording its source repository, commit, and original path.

## Clone the complete library

To clone this repository and all tracked source repositories:

```powershell
git clone --recurse-submodules https://github.com/1589558381-crypto/codex-skills.git
```

If you already cloned it without submodules:

```powershell
git submodule update --init --recursive
```
