#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAMEWORK_DIR="$ROOT_DIR/Packages/CodeEditLanguages/CodeLanguagesContainer.xcframework"
FRAMEWORK_BINARY="$FRAMEWORK_DIR/macos-arm64_x86_64/CodeLanguages_Container.framework/Versions/A/CodeLanguages_Container"

if [[ -f "$FRAMEWORK_BINARY" ]]; then
  exit 0
fi

cat >&2 <<'EOF'
error: Missing CodeLanguagesContainer.xcframework.

CodeEditLanguages uses a generated binary framework for bundled tree-sitter
language parsers. The framework is intentionally ignored by Git because it is
larger than GitHub's 100 MB file limit.

Generate it before building Lumi:

  cd Packages/CodeEditLanguages
  ./build_framework.sh

EOF

exit 1
