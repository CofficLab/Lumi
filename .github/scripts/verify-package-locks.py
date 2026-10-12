#!/usr/bin/env python3
"""
verify-package-locks.py — compare shared dependencies between two Package.resolved files.

Reads the main project lock and the ACP lock, then reports:
  * Dependencies present in one but not the other (informational).
  * Dependencies present in both but with different repository locations or
    revisions (ERROR).

Usage:
  verify-package-locks.py <main-lock> <acp-lock> [--strict]

Exit codes:
  0  all shared dependencies have matching revisions
  1  one or more shared dependencies have mismatched revisions
  2  usage error or file not found
"""

import json
import re
import sys
from pathlib import Path
from typing import Dict, Optional, Tuple


def load_resolved(path: Path) -> Dict[str, dict]:
    """Load a Package.resolved file and return a dict of identity -> pin."""
    if not path.exists():
        print(f"❌ File not found: {path}", file=sys.stderr)
        sys.exit(2)

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in {path}: {e}", file=sys.stderr)
        sys.exit(2)

    pins = {}
    for pin in data.get("pins", []):
        identity = pin.get("identity", "")
        if identity:
            pins[identity] = pin
    return pins


def get_revision(pin: dict) -> Optional[str]:
    """Extract the revision from a pin entry."""
    state = pin.get("state", {})
    return state.get("revision")


def get_version(pin: dict) -> Optional[str]:
    """Extract the version from a pin entry."""
    state = pin.get("state", {})
    return state.get("version")


def normalize_location(pin: dict) -> str:
    """Normalize a source-control URL for stable lock-file comparison."""
    location = str(pin.get("location", "")).strip().lower()
    location = re.sub(r"\.git/?$", "", location).rstrip("/")
    return location


def compare_locks(
    main_pins: Dict[str, dict],
    acp_pins: Dict[str, dict],
    strict: bool = False,
) -> Tuple[int, int, int]:
    """
    Compare two sets of pins.

    Returns (matches, mismatches, unique_count).
    """
    main_identities = set(main_pins.keys())
    acp_identities = set(acp_pins.keys())

    shared = main_identities & acp_identities
    only_main = main_identities - acp_identities
    only_acp = acp_identities - main_identities

    matches = 0
    mismatches = 0

    for identity in sorted(shared):
        main_rev = get_revision(main_pins[identity])
        acp_rev = get_revision(acp_pins[identity])

        main_location = normalize_location(main_pins[identity])
        acp_location = normalize_location(acp_pins[identity])

        if main_rev == acp_rev and main_location == acp_location:
            matches += 1
        else:
            mismatches += 1
            main_ver = get_version(main_pins[identity]) or "unknown"
            acp_ver = get_version(acp_pins[identity]) or "unknown"
            print(f"  ❌ {identity}:")
            print(f"     main: {main_ver} ({main_rev[:12] if main_rev else 'unknown'}...)")
            print(f"     acp:  {acp_ver} ({acp_rev[:12] if acp_rev else 'unknown'}...)")
            if main_location != acp_location:
                print(f"     main source: {main_location or 'unknown'}")
                print(f"     acp source:  {acp_location or 'unknown'}")

    if only_main:
        print(f"\n  ℹ️  {len(only_main)} dependencies only in main lock:")
        for identity in sorted(only_main)[:5]:
            print(f"     - {identity}")
        if len(only_main) > 5:
            print(f"     ... and {len(only_main) - 5} more")

    if only_acp:
        print(f"\n  ℹ️  {len(only_acp)} dependencies only in ACP lock:")
        for identity in sorted(only_acp)[:5]:
            print(f"     - {identity}")
        if len(only_acp) > 5:
            print(f"     ... and {len(only_acp) - 5} more")

    return matches, mismatches, len(only_main) + len(only_acp)


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: verify-package-locks.py <main-lock> <acp-lock> [--strict]", file=sys.stderr)
        return 2

    main_lock = Path(sys.argv[1])
    acp_lock = Path(sys.argv[2])
    strict = "--strict" in sys.argv

    main_pins = load_resolved(main_lock)
    acp_pins = load_resolved(acp_lock)

    print(f"📋 Main lock: {len(main_pins)} dependencies")
    print(f"📋 ACP lock:  {len(acp_pins)} dependencies")
    print()

    matches, mismatches, unique_count = compare_locks(main_pins, acp_pins, strict)

    print()
    print(f"Summary: {matches} matching, {mismatches} mismatched, {unique_count} unique to one lock")

    if mismatches > 0:
        print()
        print("❌ Shared dependencies have different sources or revisions!")
        print("   This may cause dependency substitution, duplicate code, or version conflicts.")
        return 1

    if strict and unique_count > 0:
        print()
        print("❌ --strict mode: unique dependencies detected")
        return 1

    print()
    print("✅ All shared dependencies have matching revisions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
