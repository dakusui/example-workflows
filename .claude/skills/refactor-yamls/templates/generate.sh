#!/usr/bin/env bash
# Usage:
#   generate.sh [OUT_DIR]
#
# Assembles .refactoring/refactored/ sources into OUT_DIR (default: .refactoring/sandbox).
# _-prefixed keys (private jq++ variables) are stripped from all output files.
#
# Typical workflow:
#   generate.sh                                 # build into .refactoring/sandbox (default)
#   diff -r .refactoring/sandbox .refactoring/generated
#   generate.sh .refactoring/generated          # promote to .refactoring/generated when satisfied

set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
_SN="refactor-yamls"
for _d in \
    "${REPO_ROOT}/.claude/skills/${_SN}/bin" \
    "${HOME}/.claude/skills/${_SN}/bin" \
    "${HOME}/.codex/skills/${_SN}/bin"; do
  [ -d "${_d}" ] && { SKILL_BIN="${_d}"; break; }
done
TARGET_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${1:-${TARGET_DIR}/.refactoring/sandbox}"
export JF_PATH="${TARGET_DIR}/.refactoring/refactored/shared"

# ── assemble ──────────────────────────────────────────────────────────────────
# Adjust these lines to match the source subdirectory structure.
"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}" "${TARGET_DIR}/.refactoring/refactored"
# Add one line per subdirectory, e.g.:
# "${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/subdir" "${TARGET_DIR}/.refactoring/refactored/subdir"

# ── strip private _-prefixed keys ─────────────────────────────────────────────
while IFS= read -r f; do
  tmp="$(mktemp)"
  "${SKILL_BIN}/ystrip" "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
done < <(find "${OUT_DIR}" -name "*.yaml" | sort)
