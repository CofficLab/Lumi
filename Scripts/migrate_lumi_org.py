#!/usr/bin/env python3
"""
migrate-lumi-org.py — 把 Lumi 系列仓库的依赖 URL 从 CofficLab 改到 lumi-softworks。

对每个仓库目录：
  1. git remote set-url origin → lumi-softworks
  2. Package.swift / README*.md 中的 github.com/CofficLab/<Repo> → github.com/lumi-softworks/<Repo>
  3. 提交并推送，打 patch tag

用法:
  migrate-lumi-org.py --repos LumiKernel LumiLogging
  migrate-lumi-org.py --repos ... --no-tag
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

COFF = "/Volumes/Data/Code/Coffic"
OLD_OWNER = "CofficLab"
NEW_OWNER = "lumi-softworks"

# 所有已迁移到 lumi-softworks 的仓库名
MIGRATED = [
    "LumiUI", "LumiProviders", "LumiKernel", "LumiLocalization", "LumiLogging",
    "LumiSettings", "LumiThemePack", "LumiKitReminder", "LumiStoreKit",
    "LumiBookletMaker", "LumiIllustrations",
    "LumiPluginAbout", "LumiPluginActivityBar", "LumiPluginBookletMaker",
    "LumiPluginCommand", "LumiPluginHydrationReminder", "LumiPluginIdleTime",
    "LumiPluginPluginManager", "LumiPluginSettingView", "LumiPluginStorage",
    "LumiPluginThemeManager", "LumiPluginThemePack", "LumiPluginToast",
]


def run(args, cwd=None, check=True):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if check and r.returncode != 0:
        print(f"    ! {' '.join(args[:3])} failed: {r.stderr.strip()[:200]}")
    return r


def migrate(repo: str, tag: bool = True) -> bool:
    d = Path(COFF) / repo
    if not (d / ".git").exists():
        print(f"[SKIP] {repo}: 无本地 clone")
        return False

    # 0) 同步远端
    run(["git", "fetch", "--tags", "origin"], cwd=d, check=False)
    st = run(["git", "status", "-sb"], cwd=d)
    if "behind" in st.stdout:
        run(["git", "pull", "--ff-only", "origin", "main"], cwd=d)
        print(f"    pulled latest")

    # 1) remote 改向
    run(["git", "remote", "set-url", "origin",
         f"https://github.com/{NEW_OWNER}/{repo}.git"], cwd=d)

    # 2) 替换文本引用
    changed = []
    for f in sorted(d.rglob("*")):
        if not f.is_file():
            continue
        rel = f.relative_to(d)
        s = str(rel)
        if s.startswith((".git/", ".build/", "build/")) or "/.build/" in s:
            continue
        if f.suffix not in (".swift", ".md", ".yml", ".yaml", ".json", ".py", ".sh", ".resolved"):
            continue
        try:
            raw = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        new = raw
        for m in MIGRATED:
            new = new.replace(f"https://github.com/{OLD_OWNER}/{m}.git",
                              f"https://github.com/{NEW_OWNER}/{m}.git")
            new = new.replace(f"https://github.com/{OLD_OWNER}/{m})",
                              f"https://github.com/{NEW_OWNER}/{m})")
        if new != raw:
            f.write_text(new, encoding="utf-8")
            changed.append(str(rel))

    if not changed:
        print(f"[OK] {repo}: 无需改动内容")
        return True

    run(["git", "add", "-A"], cwd=d)
    # 只提交属于本仓库的文件（排除嵌套 clone）
    run(["git", "commit", "-m",
         "chore(deps): update repository URLs after transfer to lumi-softworks org\n\n"
         "Point the dependency URLs at the new owner. The packages now live under\n"
         "the lumi-softworks organization, and GitHub's redirect alone would still\n"
         "leave the resolved pins recording the old location."], cwd=d)
    r = run(["git", "push", "origin", "main"], cwd=d)
    if r.returncode != 0:
        print(f"[FAIL] {repo}: push 失败")
        return False
    print(f"    committed: {', '.join(changed)}")

    # 3) patch tag
    if tag:
        tags = run(["git", "tag", "--sort=-v:refname"], cwd=d).stdout.split()
        nums = [t for t in tags if re.fullmatch(r"\d+\.\d+\.\d+", t)]
        if nums:
            latest = nums[0]
            major, minor, patch = (int(x) for x in latest.split("."))
            new_tag = f"{major}.{minor}.{patch + 1}"
            run(["git", "tag", "-a", new_tag, "-m",
                 f"{new_tag} — transferred to lumi-softworks org"], cwd=d)
            run(["git", "push", "origin", new_tag], cwd=d)
            print(f"    tagged {new_tag}")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repos", nargs="+", required=True)
    ap.add_argument("--no-tag", action="store_true")
    a = ap.parse_args()

    ok = True
    for repo in a.repos:
        print(f"=== {repo} ===")
        if not migrate(repo, tag=not a.no_tag):
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
