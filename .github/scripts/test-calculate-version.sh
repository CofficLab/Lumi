#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lumi-calculate-version-test.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

setup_repository() {
  local version="$1"
  local tag="$2"

  mkdir -p "${TEST_ROOT}/repository/.github/scripts" "${TEST_ROOT}/repository/LumiApp/Config"
  cp "${REPO_ROOT}/.github/scripts/bump-version.sh" "${TEST_ROOT}/repository/.github/scripts/"
  cp "${REPO_ROOT}/.github/scripts/calculate-version.sh" "${TEST_ROOT}/repository/.github/scripts/"
  printf 'MARKETING_VERSION = %s;\n' "${version}" > "${TEST_ROOT}/repository/LumiApp/Config/Lumi-Release.xcconfig"

  git -C "${TEST_ROOT}/repository" init -q
  git -C "${TEST_ROOT}/repository" config user.email "test@example.com"
  git -C "${TEST_ROOT}/repository" config user.name "Version Test"
  git -C "${TEST_ROOT}/repository" add .
  git -C "${TEST_ROOT}/repository" commit -q -m "chore: initialize test repository"
  git -C "${TEST_ROOT}/repository" tag "${tag}"
}

add_commit() {
  local message="$1"
  printf '%s\n' "${message}" >> "${TEST_ROOT}/repository/change.txt"
  git -C "${TEST_ROOT}/repository" add change.txt
  git -C "${TEST_ROOT}/repository" commit -q -m "${message}"
}

assert_version() {
  local expected="$1"
  local actual
  actual="$(cd "${TEST_ROOT}/repository" && bash .github/scripts/calculate-version.sh 2>/dev/null)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL: expected ${expected}, got ${actual}" >&2
    exit 1
  fi
}

rm -rf "${TEST_ROOT}/repository"
setup_repository "6.0.0" "v5.25.0"
add_commit "feat: add a release feature"
assert_version "6.0.0"

rm -rf "${TEST_ROOT}/repository"
setup_repository "5.24.3" "v5.25.0"
add_commit "fix: repair a release issue"
assert_version "5.25.1"

rm -rf "${TEST_ROOT}/repository"
setup_repository "5.25.0" "v5.25.0"
add_commit "feat: add another release feature"
assert_version "5.26.0"

echo "calculate-version tests passed"
