#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRAMEWORK_DIR="$ROOT_DIR/Packages/EditorLanguages/CodeLanguagesContainer.xcframework"

if [[ -d "$FRAMEWORK_DIR" ]]; then
  FRAMEWORK_BINARY="$(
    find "$FRAMEWORK_DIR" \
      -path '*/CodeLanguages_Container.framework/Versions/*/CodeLanguages_Container' \
      -type f \
      | head -n 1
  )"
  if [[ -n "${FRAMEWORK_BINARY:-}" && -f "$FRAMEWORK_BINARY" ]]; then
    exit 0
  fi
fi

cat >&2 <<'EOF'
error: Missing CodeLanguagesContainer.xcframework.

EditorLanguages uses a generated binary framework for bundled tree-sitter
language parsers. The framework is intentionally ignored by Git because it is
larger than GitHub's 100 MB file limit.

Generate it before building Lumi:

  cd Packages/EditorLanguages
  ./build_framework.sh

EOF

exit 1
