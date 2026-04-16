---
name: refactor-and-report-sample
description: Refactor a sample under samples/ using jq++ AND write a REFACTORING_REPORT.md. Use this skill only when the user explicitly asks for both refactoring and a report in the same request. Trigger on phrases like "refactor samples/X and write the report", "refactor and report", "refactor with report", "refactor samples/X including the report", or "refactor then document".
---

# Refactor-and-Report Sample Skill

Refactor a sample and produce a `REFACTORING_REPORT.md` in one workflow.

## Steps

1. Use the `/refactor-sample` skill to perform the full refactoring (steps 1–5: analyze, design, create jq++ sources, generate output, verify).

2. Use the `/refactoring-report-for-sample` skill to write `REFACTORING_REPORT.md`.

ARGUMENTS: {args}
