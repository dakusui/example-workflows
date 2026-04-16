#!/usr/bin/env bash
# Usage:
#   verify.sh [DIR_A [DIR_B]]
#
# Checks semantic equivalence between DIR_A and DIR_B.
# Defaults: DIR_A=.refactoring/generated  DIR_B=.refactoring/sandbox
#
# YAML files are compared via: yq -S '.'  (key-sorted, null-filtered)
# JSON files are compared via: jq -S .
#
# Exits 0 if all files match, non-zero if any differ.

set -euo pipefail
SAMPLE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIR_A="${1:-${SAMPLE_DIR}/.refactoring/generated}"
DIR_B="${2:-${SAMPLE_DIR}/.refactoring/sandbox}"

pass=0
fail=0

check_yaml() {
  local fa="$1" fb="$2" rel="$3"
  local out
  if out=$(diff \
      <(yq -S '.' "${fa}" | grep -v '^null$') \
      <(yq -S '.' "${fb}" | grep -v '^null$') 2>&1); then
    echo "OK:   ${rel}"
    pass=$((pass + 1))
  else
    echo "FAIL: ${rel}"
    echo "${out}" | sed 's/^/      /'
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
    *.yaml) check_yaml "${fa}" "${fb}" "${rel}" ;;
    *.json) check_json "${fa}" "${fb}" "${rel}" ;;
  esac
done < <(find "${DIR_A}" \( -name "*.yaml" -o -name "*.json" \) | sort)

echo ""
if [[ ${fail} -eq 0 ]]; then
  echo "PASS  ${pass}/${pass} files match"
else
  echo "FAIL  ${pass} passed, ${fail} failed"
fi

[[ ${fail} -eq 0 ]]
