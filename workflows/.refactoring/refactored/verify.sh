#!/usr/bin/env bash
# Usage:
#   verify.sh [DIR_A [DIR_B]]
#
# Checks that DIR_B (sandbox) contains all attributes and values present in
# DIR_A (generated baseline).  Extra attributes in DIR_B are allowed.
# Defaults: DIR_A=.refactoring/generated  DIR_B=.refactoring/sandbox
#
# YAML/JSON containment is checked via jq's `contains` (recursive object
# subset, array element subset).  On failure, a key-sorted diff is shown
# for diagnosis.
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
  local gen_json sandbox_json result
  gen_json=$(yq '.' "${fa}" | grep -v '^null$')
  sandbox_json=$(yq '.' "${fb}" | grep -v '^null$')
  result=$(printf '%s' "${sandbox_json}" | jq --argjson gen "${gen_json}" '. | contains($gen)')
  if [[ "${result}" == "true" ]]; then
    echo "OK:   ${rel}"
    pass=$((pass + 1))
  else
    echo "FAIL: ${rel}  (sandbox is missing required fields from generated)"
    diff \
      <(printf '%s\n' "${gen_json}"     | jq -S .) \
      <(printf '%s\n' "${sandbox_json}" | jq -S .) 2>&1 | head -30 | sed 's/^/      /'
    fail=$((fail + 1))
  fi
}

check_json() {
  local fa="$1" fb="$2" rel="$3"
  local gen_json sandbox_json result
  gen_json=$(jq . "${fa}")
  sandbox_json=$(jq . "${fb}")
  result=$(printf '%s' "${sandbox_json}" | jq --argjson gen "${gen_json}" '. | contains($gen)')
  if [[ "${result}" == "true" ]]; then
    echo "OK:   ${rel}"
    pass=$((pass + 1))
  else
    echo "FAIL: ${rel}  (sandbox is missing required fields from generated)"
    diff \
      <(printf '%s\n' "${gen_json}"     | jq -S .) \
      <(printf '%s\n' "${sandbox_json}" | jq -S .) 2>&1 | head -30 | sed 's/^/      /'
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
