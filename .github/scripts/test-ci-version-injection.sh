#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lumi-ci-version-test.XXXXXX")"

cleanup() {
  rm -rf "${TEST_ROOT}"
}
trap cleanup EXIT

mkdir -p \
  "${TEST_ROOT}/repository/ci_scripts" \
  "${TEST_ROOT}/repository/.github/scripts" \
  "${TEST_ROOT}/repository/AppIconDesignerApp" \
  "${TEST_ROOT}/repository/BookletMakerApp" \
  "${TEST_ROOT}/repository/CADDesignerApp" \
  "${TEST_ROOT}/repository/DatabaseManagerApp"

cp "${REPOSITORY_ROOT}/ci_scripts/ci_post_clone.sh" \
  "${TEST_ROOT}/repository/ci_scripts/"
cp "${SCRIPT_DIR}"/set-*-version.sh \
  "${TEST_ROOT}/repository/.github/scripts/"
cp \
  "${REPOSITORY_ROOT}/BookletMakerApp/BookletMaker.xcconfig" \
  "${TEST_ROOT}/repository/BookletMakerApp/BookletMaker.xcconfig"
cp \
  "${REPOSITORY_ROOT}/AppIconDesignerApp/AppIconDesigner.xcconfig" \
  "${TEST_ROOT}/repository/AppIconDesignerApp/AppIconDesigner.xcconfig"
cp \
  "${REPOSITORY_ROOT}/CADDesignerApp/CADDesigner.xcconfig" \
  "${TEST_ROOT}/repository/CADDesignerApp/CADDesigner.xcconfig"
cp \
  "${REPOSITORY_ROOT}/DatabaseManagerApp/DatabaseManager.xcconfig" \
  "${TEST_ROOT}/repository/DatabaseManagerApp/DatabaseManager.xcconfig"
run_post_clone() {
  (
    cd "${TEST_ROOT}/repository/ci_scripts"
    CI_TAG="$1" CI_BUILD_NUMBER="$2" ./ci_post_clone.sh
  )
}

assert_setting() {
  local file="$1"
  local setting="$2"
  local expected="$3"

  if ! grep -q "^${setting} = ${expected}$" "${file}"; then
    echo "FAIL: ${file} 中的 ${setting} 不是 ${expected}" >&2
    exit 1
  fi
}

run_post_clone booklet-v6.0.0 28
run_post_clone appicondesigner-v2.3.4 29
run_post_clone caddesigner-v3.4.5 30
run_post_clone databasemanager-v4.5.6 31

assert_setting "${TEST_ROOT}/repository/BookletMakerApp/BookletMaker.xcconfig" MARKETING_VERSION 6.0.0
assert_setting "${TEST_ROOT}/repository/BookletMakerApp/BookletMaker.xcconfig" CURRENT_PROJECT_VERSION 28
assert_setting "${TEST_ROOT}/repository/AppIconDesignerApp/AppIconDesigner.xcconfig" MARKETING_VERSION 2.3.4
assert_setting "${TEST_ROOT}/repository/AppIconDesignerApp/AppIconDesigner.xcconfig" CURRENT_PROJECT_VERSION 29
assert_setting "${TEST_ROOT}/repository/CADDesignerApp/CADDesigner.xcconfig" MARKETING_VERSION 3.4.5
assert_setting "${TEST_ROOT}/repository/CADDesignerApp/CADDesigner.xcconfig" CURRENT_PROJECT_VERSION 30
assert_setting "${TEST_ROOT}/repository/DatabaseManagerApp/DatabaseManager.xcconfig" MARKETING_VERSION 4.5.6
assert_setting "${TEST_ROOT}/repository/DatabaseManagerApp/DatabaseManager.xcconfig" CURRENT_PROJECT_VERSION 31

BOOKLET_CHECKSUM_BEFORE="$(shasum -a 256 "${TEST_ROOT}/repository/BookletMakerApp/BookletMaker.xcconfig")"
(
  cd "${TEST_ROOT}/repository/ci_scripts"
  CI_TAG=v9.9.9 CI_BUILD_NUMBER=32 ./ci_post_clone.sh
)
BOOKLET_CHECKSUM_AFTER="$(shasum -a 256 "${TEST_ROOT}/repository/BookletMakerApp/BookletMaker.xcconfig")"
if [[ "${BOOKLET_CHECKSUM_BEFORE}" != "${BOOKLET_CHECKSUM_AFTER}" ]]; then
  echo "FAIL: 非 app 发布 tag 不应修改 BookletMaker 版本" >&2
  exit 1
fi

if (
  cd "${TEST_ROOT}/repository/ci_scripts"
  CI_TAG=booklet-v6.0.0 ./ci_post_clone.sh
) >/dev/null 2>&1; then
  echo "FAIL: 缺少 CI_BUILD_NUMBER 时不应继续构建" >&2
  exit 1
fi

echo "PASS: Xcode Cloud 版本注入回归测试通过"
