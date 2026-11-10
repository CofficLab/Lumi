#!/usr/bin/env python3
"""
check_platform_consistency.py — 校验本地包的部署目标与依赖闭包一致。

规则：一个本地包的 platforms.macOS 必须 >= 它（传递）依赖的所有远程包与
本地包的 platforms.macOS。否则 SwiftPM 会在解析阶段报平台冲突。

用法：
    python3 Scripts/check_platform_consistency.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGES_DIR = ROOT / "Packages"

MACOS_RE = re.compile(r'\.macOS\(\s*(?:"(?P<q>[^"]+)"|\.v(?P<v>\d+))\s*\)')
PACKAGE_URL_RE = re.compile(r'\.package\(\s*url:\s*"[^"]*?/([^/"]+?)(?:\.git)?"')
PACKAGE_PATH_RE = re.compile(r'\.package\(\s*path:\s*"[^"]*?/(?:Packages/)?([A-Za-z0-9_]+)"')

# 远程包的最低 macOS 版本（AvailabilityMacro 也算在内）
REMOTE_PLATFORM = {
    "LumiKernel": (14, 0),
    "LumiLocalization": (14, 0),
    "LumiLogging": (14, 0),
    "LumiProviders": (14, 0),
    "LumiSettings": (14, 0),
    "LumiThemePack": (14, 0),
    "LumiUI": (14, 0),
    "MagicAlert": (14, 0),
    # platforms 声明是 .macOS(.v11)，但 AvailabilityMacro 把 hummingbird 2.0
    # 映射到 macOS 14.0，实际要求 14.0。
    "hummingbird": (14, 0),
    "mlx-swift": (14, 0),
    "mlx-swift-lm": (14, 0),
    "LumiPluginAbout": (14, 0),
    "LumiPluginActivityBar": (14, 0),
    "LumiPluginBookletMaker": (14, 0),
    "LumiPluginCommand": (14, 0),
    "LumiPluginHydrationReminder": (14, 0),
    "LumiPluginIdleTime": (14, 0),
    "LumiPluginPluginManager": (14, 0),
    "LumiPluginSettingView": (14, 0),
    "LumiPluginStorage": (14, 0),
    "LumiPluginThemeManager": (14, 0),
    "LumiPluginThemePack": (14, 0),
    "LumiPluginToast": (14, 0),
}


def parse_version(text: str) -> tuple:
    text = text.strip()
    if text.startswith(".v"):
        text = text[2:]
    if text.startswith("v"):
        text = text[1:]
    parts = text.split(".")
    try:
        return (int(parts[0]), int(parts[1]) if len(parts) > 1 else 0)
    except ValueError:
        return (0, 0)


def load(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    m = MACOS_RE.search(text)
    current = parse_version(m.group("q") or f"v{m.group('v')}") if m else None
    remote = {b for b in PACKAGE_URL_RE.findall(text) if b in REMOTE_PLATFORM}
    local = {n for n in PACKAGE_PATH_RE.findall(text) if n not in REMOTE_PLATFORM}
    return {"current": current, "remote": remote, "local": local}


def main() -> int:
    manifests = {}
    for pkg_dir in sorted(PACKAGES_DIR.iterdir()):
        m = pkg_dir / "Package.swift"
        if m.exists():
            manifests[pkg_dir.name] = load(m)

    # 每个包的「有效最低平台」= max(自身声明, 所有直接依赖的最低平台)
    effective = {}
    for name, info in manifests.items():
        level = info["current"] or (0, 0)
        for dep in info["remote"]:
            level = max(level, REMOTE_PLATFORM[dep])
        for dep in info["local"]:
            if dep in manifests:
                level = max(level, manifests[dep]["current"] or (0, 0))
        effective[name] = level

    # 传递闭包修正：依赖了有效平台更高的本地包时，本包也要抬到同样高度
    changed = True
    while changed:
        changed = False
        for name, info in manifests.items():
            level = effective[name]
            for dep in info["local"]:
                if dep in effective and effective[dep] > level:
                    level = effective[dep]
            if level != effective[name]:
                effective[name] = level
                changed = True

    problems = []
    for name in sorted(manifests):
        info = manifests[name]
        if info["current"] is None:
            continue
        if effective[name] > info["current"]:
            problems.append((name, info["current"], effective[name]))

    if problems:
        print("[FAIL] 以下包的部署目标低于其依赖闭包要求：")
        for name, cur, need in problems:
            print(f"  {name}: {'.'.join(map(str, cur))} < {'.'.join(map(str, need))}")
        return 1

    print(f"[OK] {len(manifests)} 个本地包的部署目标与依赖闭包一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
