# Installing Portable Skills

Two skills in this repository are general-purpose and can be installed outside of this repo:

| Skill | What it does |
|---|---|
| `refactor-yamls` | Refactor any directory of YAML/JSON files using jq++ to eliminate repetition |
| `report-refactored-yamls` | Write a `REFACTORING_REPORT.md` for any directory refactored by `refactor-yamls` |

## Prerequisites

These tools must be on `PATH` before using the skills:

- **`jq++`** — [dakusui/jqplusplus](https://github.com/dakusui/jqplusplus)
- **`yq`** — [kislyuk/yq](https://github.com/kislyuk/yq) (YAML output flag is `-y '.'`)
- **`jq`** — [stedolan/jq](https://github.com/stedolan/jq)

## Installation

### As a personal skill (available in all projects)

```bash
REPO="path/to/this/repo"   # e.g. ~/Documents/github/dakusui/istio

cp -r "${REPO}/.claude/skills/refactor-yamls"        ~/.claude/skills/
cp -r "${REPO}/.claude/skills/report-refactored-yamls" ~/.claude/skills/
chmod +x ~/.claude/skills/refactor-yamls/bin/*
```

### Into another repository

```bash
REPO="path/to/this/repo"
TARGET="path/to/other/repo"

mkdir -p "${TARGET}/.claude/skills"
cp -r "${REPO}/.claude/skills/refactor-yamls"        "${TARGET}/.claude/skills/"
cp -r "${REPO}/.claude/skills/report-refactored-yamls" "${TARGET}/.claude/skills/"
chmod +x "${TARGET}/.claude/skills/refactor-yamls/bin/*"
```

## Verification

After installing, confirm the skill bin tools are executable:

```bash
~/.claude/skills/refactor-yamls/bin/yjoin --help
~/.claude/skills/refactor-yamls/bin/yq++ --help
~/.claude/skills/refactor-yamls/bin/ysplit --help
~/.claude/skills/refactor-yamls/bin/ystrip --help
```

## Notes

- `report-refactored-yamls` contains only a `SKILL.md` — no binaries. It relies on `refactor-yamls/bin` at runtime only through the `generate.sh` and `verify.sh` scripts already deployed in the target directory.
- The `generate.sh` files produced by `refactor-yamls` search for `refactor-yamls/bin` in the repo, then `~/.claude/skills/`, then `~/.codex/skills/` — so both install locations work transparently.
