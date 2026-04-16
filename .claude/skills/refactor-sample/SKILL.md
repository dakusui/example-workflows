---
name: refactor-sample
description: Refactor a sample under the samples/ directory using jq++ and yq to eliminate repetition, producing a DRY, maintainable version. Use this skill whenever the user asks to refactor, DRY up, or reduce duplication in a sample, mentions jq++ or YAML/JSON templating for a sample, or wants to create a generate.sh for a sample. Trigger on phrases like "refactor samples/X", "refactor the X sample", "DRY up this sample", "create a jq++ version of", "reduce duplication in samples", or "generate.sh for a sample". Do NOT produce a REFACTORING_REPORT.md unless the user explicitly asks for a report (in which case use refactor-and-report-sample instead).
---

# Refactor Sample Skill

Wrapper around the `refactor-yamls` skill for samples under `samples/`.

## How to invoke

1. **Derive the target directory** from the sample name argument:
   - `TARGET_DIR` = `samples/{sample-name}` (relative to repo root)

2. **Invoke the `refactor-yamls` skill** using the Skill tool, passing `samples/{sample-name}` as the argument.

3. **Apply these sample-specific overrides** during the `refactor-yamls` workflow:

   **generate.sh template** — use `refactor-sample/templates/generate.sh` instead of the `refactor-yamls` one. It already includes `${REPO_ROOT}/samples/shared` on JF_PATH, making cross-sample shared files (e.g. `subsets.jq`) accessible by bare filename:

   ```bash
   export JF_PATH="${TARGET_DIR}/.refactoring/refactored/shared:${REPO_ROOT}/samples/shared"
   ```

   Copy commands:
   ```bash
   REPO_ROOT="$(git rev-parse --show-toplevel)"
   cp "${REPO_ROOT}/.claude/skills/refactor-sample/templates/generate.sh" \
      "samples/{sample-name}/.refactoring/refactored/generate.sh"
   cp "${REPO_ROOT}/.claude/skills/refactor-sample/templates/verify.sh" \
      "samples/{sample-name}/.refactoring/refactored/verify.sh"
   chmod +x "samples/{sample-name}/.refactoring/refactored/generate.sh" \
            "samples/{sample-name}/.refactoring/refactored/verify.sh"
   ```

---

