#!/usr/bin/env bash
# Usage:
#   verify.sh [DIR_A [DIR_B]]
#
# Checks semantic equivalence between DIR_A (generated baseline) and DIR_B
# (sandbox), with one targeted relaxation:
#
#   - All fields except root env:  strict equality (diff)
#   - Root env: only              containment — sandbox may carry extra vars
#                                 beyond what generated declares
#
# Defaults: DIR_A=.refactoring/generated  DIR_B=.refactoring/sandbox
# JSON files are compared via strict jq -S diff (no env: relaxation).
#
# Exits 0 if all files pass, non-zero if any fail.

set -euo pipefail
SAMPLE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIR_A="${1:-${SAMPLE_DIR}/.refactoring/generated}"
DIR_B="${2:-${SAMPLE_DIR}/.refactoring/sandbox}"

pass=0
fail=0

check_yaml() {
  local fa="$1" fb="$2" rel="$3"
  local err=0 out result gen_env sandbox_env

  # Strict check on everything except root env:
  if ! out=$(diff \
      <(yq -S 'del(.env)' "${fa}" | grep -v '^null$') \
      <(yq -S 'del(.env)' "${fb}" | grep -v '^null$') 2>&1); then
    echo "FAIL: ${rel}  (non-env fields differ)"
    echo "${out}" | sed 's/^/      /'
    err=1
  fi

  # Containment check on root env: only
  gen_env=$(yq '.env // {}' "${fa}")
  sandbox_env=$(yq '.env // {}' "${fb}")
  result=$(printf '%s' "${sandbox_env}" | jq --argjson gen "${gen_env}" '. | contains($gen)')
  if [[ "${result}" != "true" ]]; then
    echo "FAIL: ${rel}  (sandbox env: missing required vars from generated)"
    diff \
      <(printf '%s\n' "${gen_env}"     | jq -S .) \
      <(printf '%s\n' "${sandbox_env}" | jq -S .) 2>&1 | head -20 | sed 's/^/      /'
    err=1
  fi

  if [[ ${err} -eq 0 ]]; then
    echo "OK:   ${rel}"
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
}

check_json() {
  local fa="$1" fb="$2" rel="$3"
  local out
  if out=$(diff <(jq -S . "${fa}") <(jq -S . "${fb}") 2>&1); then
    echo "OK:   ${rel}"
    pass=$((pass + 1))
  else
    echo "FAIL: ${rel}"
    echo "${out}" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
}

while IFS= read -r fa; do
  rel="${fa#${DIR_A}/}"
  fb="${DIR_B}/${rel}"
  if [[ ! -f "${fb}" ]]; then
    echo "MISS: ${rel}  (absent in ${DIR_B})"
    fail=$((fail + 1))
    continue
  fi
  case "${fa}" in
    *.yaml|*.yml) check_yaml "${fa}" "${fb}" "${rel}" ;;
    *.json) check_json "${fa}" "${fb}" "${rel}" ;;
  esac
done < <(find "${DIR_A}" \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) | sort)

echo ""
if [[ ${fail} -eq 0 ]]; then
  echo "PASS  ${pass}/${pass} files match"
else
  echo "FAIL  ${pass} passed, ${fail} failed"
fi

[[ ${fail} -eq 0 ]]
