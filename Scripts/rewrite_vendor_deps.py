#!/usr/bin/env python3
"""
rewrite_vendor_deps.py — 把本地 Package.swift 里的 Vendor 路径依赖改回远程 URL。

只处理 .package(path: ".../Vendor/<Name>") 形式；每行改写成
.package(url: "<remote-url>", from: "<version>")。

版本来源优先级：
1. Vendor/<Name>/.upstream-version
2. 硬编码覆盖表 OVERRIDES（用于需要升到比 vendored 版本更新的上游 tag）

注意：.product(name:package:) 的 package: 参数按 URL basename 匹配，
即仓库名，与 vendored 时期一致，因此无需改动。
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Vendor 目录名 -> (远程 URL, 版本)
# 版本默认取 .upstream-version；OVERRIDES 用于本仓库已回流上游的更新版本。
URLS = {
    "LumiKernel": "https://github.com/CofficLab/LumiKernel.git",
    "LumiKitReminder": "https://github.com/CofficLab/LumiKitReminder.git",
    "LumiLocalization": "https://github.com/CofficLab/LumiLocalization.git",
    "LumiLogging": "https://github.com/CofficLab/LumiLogging.git",
    "LumiProviders": "https://github.com/CofficLab/LumiProviders.git",
    "LumiSettings": "https://github.com/CofficLab/LumiSettings.git",
    "LumiThemePack": "https://github.com/CofficLab/LumiThemePack.git",
    "LumiUI": "https://github.com/CofficLab/LumiUI.git",
    "MagicAlert": "https://github.com/nookery/MagicAlert.git",
    "hummingbird": "https://github.com/hummingbird-project/hummingbird.git",
    "mlx-swift": "https://github.com/ml-explore/mlx-swift.git",
    "mlx-swift-lm": "https://github.com/ml-explore/mlx-swift-lm.git",
}

# 所有 LumiPlugin* 远程插件包
for _name in [
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
    URLS[_name] = f"https://github.com/CofficLab/{_name}.git"

# 覆盖版本：本仓库已把改动回流上游并打了新 tag
OVERRIDES = {
    "LumiUI": "1.13.0",
    "LumiProviders": "1.22.0",
    "LumiPluginStorage": "1.2.0",
    "LumiPluginAbout": "3.0.3",
}

# LumiKitReminder 是 LumiPluginHydrationReminder 的传递依赖，
# 消费方在 Vendor 目录内部（上游包自己的 Package.swift），本仓库无直接引用。

VENDOR_REF = re.compile(
    r'\.package\(\s*path:\s*"[^"]*?/Vendor/(?P<name>[A-Za-z0-9_.-]+)"\s*\)'
)


def version_for(name: str) -> str:
    if name in OVERRIDES:
        return OVERRIDES[name]
    marker = ROOT / "Vendor" / name / ".upstream-version"
    if marker.exists():
        return marker.read_text(encoding="utf-8").strip()
    raise SystemExit(f"[FAIL] {name} 没有 .upstream-version，也没有版本覆盖")


def main() -> int:
    packages = sorted(ROOT.glob("Packages/*/Package.swift"))
    changed_files = 0
    changed_refs = 0
    unknown = set()

    for manifest in packages:
        original = manifest.read_text(encoding="utf-8")

        def replace(match: re.Match) -> str:
            nonlocal changed_refs
            name = match.group("name")
            if name not in URLS:
                unknown.add(name)
                return match.group(0)
            version = version_for(name)
            changed_refs += 1
            return f'.package(url: "{URLS[name]}", from: "{version}")'

        updated = VENDOR_REF.sub(replace, original)
        if updated != original:
            manifest.write_text(updated, encoding="utf-8")
            changed_files += 1

    if unknown:
        print(f"[FAIL] 未登记的 Vendor 包: {sorted(unknown)}")
        return 1

    print(f"改写 {changed_refs} 处 Vendor 依赖，涉及 {changed_files} 个 Package.swift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
