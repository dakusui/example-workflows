---
name: report-refactored-yamls
description: Write a REFACTORING_REPORT.md for any directory refactored by the refactor-yamls skill. Use this skill whenever the user asks to write the report, produce REFACTORING_REPORT.md, document the refactoring results, or summarize the metrics for a refactored directory. Trigger on phrases like "write the report for X", "produce the refactoring report", "document the refactoring", or "REFACTORING_REPORT".
---

# Report Refactored YAMLs Skill

Write `{TARGET_DIR}/.refactoring/refactored/REFACTORING_REPORT.md` summarizing the outcome of a jq++ refactoring produced by the `refactor-yamls` skill.

## Arguments

- **TARGET_DIR** — the directory that was refactored (e.g. `infra/k8s/staging`, `samples/helloworld`)

## What you need before writing

- `{TARGET_DIR}/.refactoring/generated/` populated (run `generate.sh` if not yet done)
- `{TARGET_DIR}/.refactoring/refactored/` populated with `.yaml++` / `.json++` sources

## Skill Utilities

Locate the skill's `bin/` directory at runtime:

```bash
_SN="report-refactored-yamls"
for _d in \
    "$(git rev-parse --show-toplevel 2>/dev/null)/.claude/skills/${_SN}/bin" \
    "${HOME}/.claude/skills/${_SN}/bin" \
    "${HOME}/.codex/skills/${_SN}/bin"; do
    [ -d "${_d}" ] && { SKILL_BIN="${_d}"; break; }
done
```

### `duplication.py`

Measures the structural duplication ratio of a set of YAML/JSON files. It finds all repeated sub-tree fragments (sized ≥ 3 key-value pairs) across the input and reports what fraction of the total structure is redundant repetition.

```bash
python3 "${SKILL_BIN}/duplication.py" <file-or-directory> [more files/dirs...]
```

Sample output:
```
Files scanned        : 6
Total size           : 238
Duplicated excess    : 63
DuplicationRatio     : 0.264706
Maximal dup groups   : 4
```

- **Total size** — total key-value pairs across all parsed documents
- **Duplicated excess** — key-value pairs that are copies of something else in the same file set
- **DuplicationRatio** — `duplicated_excess / total_size`; 0.0 = no duplication, 1.0 = everything is a copy

## Metrics

### Line and word counts

Collect line and word counts with `wc -lw`:

```bash
# Generated baseline
find {TARGET_DIR}/.refactoring/generated -name "*.yaml" -o -name "*.json" | sort | xargs wc -lw

# Refactored sources (exclude generate.sh and verify.sh)
find {TARGET_DIR}/.refactoring/refactored -name "*.yaml++" -o -name "*.json++" | sort | xargs wc -lw

# Shared subset only
find {TARGET_DIR}/.refactoring/refactored/shared -name "*.yaml++" -o -name "*.json++" 2>/dev/null | sort | xargs wc -lw
```

Use `.generated/` as the baseline — not the originals. The originals may contain comments that are stripped during the jq++ → yq round-trip, which would inflate the apparent savings. The generated files represent what the refactored sources actually produce.

### Duplication analysis

Run `duplication.py` against both directories:

```bash
python3 "${SKILL_BIN}/duplication.py" {TARGET_DIR}/.refactoring/generated
python3 "${SKILL_BIN}/duplication.py" {TARGET_DIR}/.refactoring/refactored
```

Record the `DuplicationRatio` from each run. The "shared" column in the table is not applicable for duplication (leave it as `—`).

## Verification status

Run `verify.sh` and record the result:

```bash
{TARGET_DIR}/.refactoring/refactored/verify.sh
```

Report PASS or FAIL. On FAIL, list the files that differ.

## Report structure

```markdown
# Refactoring Report: {TARGET_DIR}

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | N | N | N | −N (−X%) |
| Words | N | N | N | −N (−X%) |
| DuplicationRatio | X.X% | X.X% | — | −X.X pp |

## Verification

PASS / FAIL — N/N files match.

## Findings

[Prose: what patterns were found and how jq++ addressed them.]
```

Express `DuplicationRatio` as a percentage (e.g. `26.5%`) and the change in percentage points (pp), e.g. `−24.4 pp`.

## Findings guidance

Describe what patterns were found and how jq++ addressed them. Include specific numbers where interesting — for example: "Both Deployments were identical except for 3 fields (version label, selector, image tag), reducing 35 repetitive lines to a 6-line base and two 10-line variants."

Incorporate the duplication ratio change to give a structural perspective on the improvement: a large drop (e.g. 26% → 2%) signals heavy cross-file repetition that was successfully factored out into shared bases; a modest drop (e.g. 5% → 2%) suggests the files were already fairly DRY and the main gain is in named abstractions rather than raw deduplication. Note any limitations encountered, such as stripped comments or array merge constraints.

ARGUMENTS: {args}
