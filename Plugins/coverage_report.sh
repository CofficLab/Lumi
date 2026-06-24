#!/usr/bin/env bash
# Measure pure-logic source-file coverage for a single SwiftPM plugin.
#
# Usage: ./coverage_report.sh <PluginDirName> [-- <extra swift-test args>]
#
# Runs `swift test --enable-code-coverage` for the plugin, then reports per-file
# line coverage ONLY for files under Sources/ that are NOT SwiftUI/AppKit views
# (files containing `import SwiftUI`/`import AppKit` or named *View*.swift are
# excluded as UI). Prints a per-file table and the plugin's pure-logic coverage.
set -euo pipefail

PLUGIN="${1:?usage: coverage_report.sh <PluginDirName> [-- <args>]}"
shift
EXTRA_ARGS=()
if [[ "${1:-}" == "--" ]]; then
    shift
    EXTRA_ARGS=("$@")
fi

ROOT="/Users/angel/Code/Coffic/Lumi/Plugins/$PLUGIN"
cd "$ROOT"

# Run with coverage instrumentation. Ignore failures (broken pre-existing tests
# shouldn't block coverage measurement); coverage data is still emitted.
set +u
if ! swift test --enable-code-coverage "${EXTRA_ARGS[@]}" >/tmp/cov_test.log 2>&1; then
    echo "⚠️  swift test exited non-zero (coverage data may be partial); see /tmp/cov_test.log"
fi
set -u

PROFDATA="$(find .build -name "default.profdata" | head -1)"
if [[ -z "$PROFDATA" ]]; then
    echo "❌ no coverage profdata found for $PLUGIN" >&2
    exit 1
fi

# The xctest binary path: <Plugin>PackageTests.xctest/Contents/MacOS/<Plugin>PackageTests
BIN="$(find .build -name "${PLUGIN}PackageTests.xctest" -type d | head -1)"
BIN="${BIN}/Contents/MacOS/${PLUGIN}PackageTests"
if [[ ! -x "$BIN" ]]; then
    echo "❌ test binary not found at $BIN" >&2
    exit 1
fi

# Identify pure-logic source files: under Sources/, skip SwiftUI/AppKit views.
ALL_SRCS="$(find Sources -name '*.swift' | sort)"
LOGIC_SRCS=()
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if grep -qE 'import (SwiftUI|AppKit)' "$f" 2>/dev/null; then continue; fi
    if [[ "$f" == *View.swift || "$f" == *Views/* ]]; then continue; fi
    LOGIC_SRCS+=("$f")
done <<< "$ALL_SRCS"

if [[ ${#LOGIC_SRCS[@]} -eq 0 ]]; then
    echo "ℹ️  no pure-logic source files identified in $PLUGIN (all UI/IO)"
    exit 0
fi

printf '== %s: pure-logic coverage (%d files) ==\n' "$PLUGIN" "${#LOGIC_SRCS[@]}"
printf '%-58s %6s %6s %8s\n' "FILE" "LINES" "COVERED" "%"

tot_lines=0
tot_cov=0
for f in "${LOGIC_SRCS[@]}"; do
    # llvm-cov report needs an absolute path to match coverage records.
    abs="$ROOT/$f"
    # llvm-cov report columns: 1=Filename 8=Lines 9=MissedLines 10=LineCover%
    # Match the data row (the one starting with the absolute file path).
    line=$(xcrun llvm-cov report "$BIN" -instr-profile="$PROFDATA" "$abs" 2>/dev/null \
           | awk -v f="$abs" '$1==f && NF>=10 {print $8, $9, $10}')
    read -r l missed pct <<< "$line"
    [[ -z "${pct:-}" ]] && { l=0; missed=0; pct="0.00"; }
    l=${l:-0}; missed=${missed:-0}
    pct="${pct%\%}"
    c=$(( l > 0 ? l - missed : 0 ))
    tot_lines=$((tot_lines + l))
    tot_cov=$((tot_cov + c))
    short="${f#Sources/}"
    printf '%-58s %6s %6s %7s%%\n' "$short" "$l" "$c" "$pct"
done

if [[ $tot_lines -gt 0 ]]; then
    overall=$(awk "BEGIN{printf \"%.2f\", ($tot_cov/$tot_lines)*100}")
else
    overall="0.00"
fi
printf '%-58s %6s %6s %7s%%\n' "TOTAL (pure-logic)" "$tot_lines" "$tot_cov" "$overall"
