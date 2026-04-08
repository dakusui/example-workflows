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
export JF_PATH="${TARGET_DIR}/.refactoring/refactored/shared:${TARGET_DIR}/.refactoring/refactored/shared/steps"

# ── assemble ──────────────────────────────────────────────────────────────────
REFACTORED="${TARGET_DIR}/.refactoring/refactored"

mkdir -p "${OUT_DIR}/deploy-cloudrun" \
         "${OUT_DIR}/create-cloud-deploy-release" \
         "${OUT_DIR}/get-gke-credentials"

"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/deploy-cloudrun"             "${REFACTORED}/deploy-cloudrun"
"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/create-cloud-deploy-release" "${REFACTORED}/create-cloud-deploy-release"
"${SKILL_BIN}/yjoin" --out-dir "${OUT_DIR}/get-gke-credentials"         "${REFACTORED}/get-gke-credentials"

# Rename *.yaml → *.yml for GitHub Actions workflow files
for f in \
    "${OUT_DIR}/deploy-cloudrun/cloudrun-buildpacks.yaml" \
    "${OUT_DIR}/deploy-cloudrun/cloudrun-docker.yaml" \
    "${OUT_DIR}/deploy-cloudrun/cloudrun-declarative.yaml" \
    "${OUT_DIR}/deploy-cloudrun/cloudrun-source.yaml" \
    "${OUT_DIR}/create-cloud-deploy-release/cloud-deploy-to-cloud-run.yaml" \
    "${OUT_DIR}/get-gke-credentials/gke-build-deploy.yaml"; do
  [[ -f "${f}" ]] && mv "${f}" "${f%.yaml}.yml"
done

# ── strip private _-prefixed keys ─────────────────────────────────────────────
while IFS= read -r f; do
  tmp="$(mktemp)"
  "${SKILL_BIN}/ystrip" "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
done < <(find "${OUT_DIR}" \( -name "*.yaml" -o -name "*.yml" \) | sort)
