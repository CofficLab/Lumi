#!/usr/bin/env python3
"""
raise_deployment_targets.py — 把本地包的部署目标抬回 macOS 14.0。

背景
----
远程上游包（LumiUI / LumiProviders / LumiKernel 等）声明的 platforms 是
macOS 14.0。本地包若声明 .macOS("13.1") 且依赖这些远程包，SwiftPM 会报：

    error: the library 'X' requires macos 14.0, but depends on the product
           'Y' which requires macos 14.0

所以只要本地包的（传递）依赖闭包里含远程包，部署目标就不能低于 14.0。

用法：
    python3 Scripts/raise_deployment_targets.py           # 报告将要改动的包
    python3 Scripts/raise_deployment_targets.py --apply   # 实际改写
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGES_DIR = ROOT / "Packages"

# 远程依赖的包名 -> 它们的最低 macOS 版本
REMOTE_PLATFORM = {
    "LumiKernel": "14.0",
    "LumiLocalization": "14.0",
    "LumiLogging": "14.0",
    "LumiProviders": "14.0",
    "LumiSettings": "14.0",
    "LumiThemePack": "14.0",
    "LumiUI": "14.0",
    "MagicAlert": "14.0",
    # hummingbird 的 platforms 声明是 .macOS(.v11)，但它的 AvailabilityMacro
    # 把 `hummingbird 2.0` 映射到 macOS 14.0（见上游 Package.swift 的
    # AvailabilityMacro=hummingbird 2.0:macOS 14.0），因此实际要求 14.0。
    "hummingbird": "14.0",
    "mlx-swift": "14.0",
    "mlx-swift-lm": "14.0",
}
for _n in [
    "LumiPluginAbout",
    "LumiPluginActivityBar",
    "LumiPluginBookletMaker",
    "LumiPluginCommand",
    "LumiPluginHydrationReminder",
    "LumiPluginIdleTime",
    "LumiPluginPluginManager",
    "LumiPluginSettingView",
    "LumiPluginStorage",
    "LumiPluginThemeManager",
    "LumiPluginThemePack",
    "LumiPluginToast",
]:
    REMOTE_PLATFORM[_n] = "14.0"

# 远程 URL basename -> 包名（用于识别 .package(url:) 依赖）
URL_BASENAME = {url.rsplit("/", 1)[-1].removesuffix(".git"): name
                for name, url in [
                    ("LumiKernel", "LumiKernel"), ("LumiLocalization", "LumiLocalization"),
                    ("LumiLogging", "LumiLogging"), ("LumiProviders", "LumiProviders"),
                    ("LumiSettings", "LumiSettings"), ("LumiThemePack", "LumiThemePack"),
                    ("LumiUI", "LumiUI"), ("MagicAlert", "MagicAlert"),
                    ("hummingbird", "hummingbird"), ("mlx-swift", "mlx-swift"),
                    ("mlx-swift-lm", "mlx-swift-lm"),
                    ("LumiPluginAbout", "LumiPluginAbout"),
                    ("LumiPluginActivityBar", "LumiPluginActivityBar"),
                    ("LumiPluginBookletMaker", "LumiPluginBookletMaker"),
                    ("LumiPluginCommand", "LumiPluginCommand"),
                    ("LumiPluginHydrationReminder", "LumiPluginHydrationReminder"),
                    ("LumiPluginIdleTime", "LumiPluginIdleTime"),
                    ("LumiPluginPluginManager", "LumiPluginPluginManager"),
                    ("LumiPluginSettingView", "LumiPluginSettingView"),
                    ("LumiPluginStorage", "LumiPluginStorage"),
                    ("LumiPluginThemeManager", "LumiPluginThemeManager"),
                    ("LumiPluginThemePack", "LumiPluginThemePack"),
                    ("LumiPluginToast", "LumiPluginToast"),
                ]}

MACOS_RE = re.compile(r'\.macOS\(\s*(?:"(?P<q>[^"]+)"|\.v(?P<v>\d+))\s*\)')
PACKAGE_URL_RE = re.compile(r'\.package\(\s*url:\s*"[^"]*?/([^/"]+?)(?:\.git)?"')
PACKAGE_PATH_RE = re.compile(r'\.package\(\s*path:\s*"[^"]*?/(?:Packages/)?([A-Za-z0-9_]+)"')


def parse_version(text: str) -> tuple:
    """'13.1' -> (13, 1); 'v14' -> (14, 0)"""
    if text is None:
        return (0, 0)
    text = text.strip()
    if text.startswith(".v"):
        text = text[2:]
    if text.startswith("v"):
        text = text[1:]
    parts = text.split(".")
    try:
        major = int(parts[0])
        minor = int(parts[1]) if len(parts) > 1 else 0
    except ValueError:
        return (0, 0)
    return (major, minor)


def load_manifest(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    m = MACOS_RE.search(text)
    current = parse_version(m.group("q") or f"v{m.group('v')}") if m else (0, 0)

    remote = set()
    for basename in PACKAGE_URL_RE.findall(text):
        name = URL_BASENAME.get(basename)
        if name:
            remote.add(name)

    local = set()
    for name in PACKAGE_PATH_RE.findall(text):
        if name not in URL_BASENAME:
            local.add(name)

    return {"path": path, "current": current, "remote": remote, "local": local,
            "has_platforms": bool(m)}


def main() -> int:
    apply = "--apply" in sys.argv
    manifests = {}
    for pkg_dir in sorted(PACKAGES_DIR.iterdir()):
        manifest = pkg_dir / "Package.swift"
        if manifest.exists():
            manifests[pkg_dir.name] = load_manifest(manifest)

    # 传递闭包：一个包被标记为「需要 14.0」，其所有本地依赖者也需要 14.0
    needs = set()
    changed = True
    while changed:
        changed = False
        for name, info in manifests.items():
            if name in needs:
                continue
            # 直接依赖远程 14.0 包，或依赖了某个 needs 包
            direct_remote = any(
                REMOTE_PLATFORM.get(dep, "0") == "14.0" for dep in info["remote"]
            )
            indirect = any(dep in needs for dep in info["local"])
            if direct_remote or indirect:
                needs.add(name)
                changed = True

    targets = []
    for name in sorted(needs):
        info = manifests[name]
        if info["current"] < (14, 0):
            targets.append((name, info["current"]))

    print(f"需要抬到 macOS 14.0 的本地包：{len(targets)} 个")
    for name, cur in targets:
        print(f"  {name}  ({'.'.join(map(str, cur))} -> 14.0)")

    if not apply:
        print("\n（预演模式，加 --apply 实际改写）")
        return 0

    for name, _ in targets:
        manifest = manifests[name]["path"]
        text = manifest.read_text(encoding="utf-8")
        # 保留原有写法风格：字符串形式 "13.1" -> "14.0"，.v14 保持
        new_text, n = MACOS_RE.subn(lambda mm: (
            '.macOS("14.0")' if mm.group("q") is not None else '.macOS(.v14)'
        ), text, count=1)
        if n:
            manifest.write_text(new_text, encoding="utf-8")

    print(f"\n已改写 {len(targets)} 个 Package.swift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
