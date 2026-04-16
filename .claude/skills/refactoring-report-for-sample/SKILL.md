---
name: refactoring-report-for-sample
description: Write a REFACTORING_REPORT.md for a refactored sample under samples/. Use this skill whenever the user asks to write the report, produce REFACTORING_REPORT.md, document the refactoring results, or summarize the metrics for a refactored sample. Trigger on phrases like "write the report for samples/X", "produce the refactoring report", "document the refactoring", or "REFACTORING_REPORT".
---

# Refactoring Report for Sample Skill

Wrapper around the `report-refactored-yamls` skill for samples under `samples/`.

## How to invoke

1. **Derive the target directory** from the sample name argument:
   - `TARGET_DIR` = `samples/{sample-name}` (relative to repo root)

2. **Invoke the `report-refactored-yamls` skill** using the Skill tool, passing `samples/{sample-name}` as the argument.

ARGUMENTS: {args}
