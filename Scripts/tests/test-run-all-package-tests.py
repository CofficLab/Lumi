#!/usr/bin/env python3
"""
回归测试：Scripts/run-all-package-tests.sh 的退出码语义。

背景：
    该脚本是全仓 `swift test` 的唯一入口。在修复之前，脚本末尾只 `cat` 汇总摘要，
    即使有包测试失败也会退出 0 —— 把它当作 CI 门禁会产生"假绿"。

本测试用临时假仓库 + PATH 中的 `swift` 桩程序驱动脚本：
    - 不运行任何真实 Swift 包
    - 不访问网络
    - 不依赖本机 Xcode / SPM 缓存

覆盖：
    1. 全部包成功 → 退出 0，FAILED.txt 为空
    2. 某个包 `swift test` 返回非零 → 脚本退出非零，FAILED.txt 含该包名
    3. 某个包缺失 rc 文件 → 脚本退出非零，FAILED.txt 含该包名
    4. 多个包失败 → 全部出现在 FAILED.txt 中
    5. 汇总摘要仍然打印（保留现有可观测性）
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "Scripts" / "run-all-package-tests.sh"

STUB_TEMPLATE = """#!/bin/bash
# `swift` 桩程序：按当前工作目录（包名）返回预设退出码。
# 控制目录路径由环境变量 LUMI_TEST_SWIFT_STUB 控制。
control="$LUMI_TEST_SWIFT_STUB"
pkg="$(basename "$PWD")"

if [ -f "$control/$pkg.kill" ]; then
    # 模拟进程在写入 rc 之前消失：杀掉父 shell，使 rc 文件缺失。
    kill -9 "$PPID" 2>/dev/null
    exit 137
fi

if [ -f "$control/$pkg.rc" ]; then
    # 控制文件内容即该包 `swift test` 的退出码。
    rc="$(cat "$control/$pkg.rc")"
    echo "fake swift test output for $pkg (rc=$rc)"
    exit "$rc"
fi

echo "fake swift test output for $pkg"
exit 0
"""


def build_fake_repo(tmp: Path, packages: list) -> Path:
    """构造临时假仓库：Scripts/ + Packages/<pkg>/Tests/。"""
    repo = tmp / "repo"
    (repo / "Scripts").mkdir(parents=True)
    shutil.copy2(SCRIPT, repo / "Scripts" / "run-all-package-tests.sh")
    for pkg in packages:
        (repo / "Packages" / pkg / "Tests").mkdir(parents=True)
    return repo


def build_stub(tmp: Path) -> Path:
    """构造 PATH 中的 `swift` 桩程序目录。"""
    stub_dir = tmp / "stub"
    stub_dir.mkdir()
    stub = stub_dir / "swift"
    stub.write_text(STUB_TEMPLATE)
    stub.chmod(0o755)
    return stub_dir


def run_script(repo: Path, stub_dir: Path, control: Path):
    """在假仓库中运行脚本，返回 (exit_code, combined_output)。"""
    env = dict(os.environ)
    env["PATH"] = f"{stub_dir}{os.pathsep}{env.get('PATH', '')}"
    env["LUMI_TEST_SWIFT_STUB"] = str(control)
    result = subprocess.run(
        ["bash", str(repo / "Scripts" / "run-all-package-tests.sh")],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(repo),
        timeout=120,
    )
    return result.returncode, result.stdout + result.stderr


def failed_packages(repo: Path) -> list:
    """读取 FAILED.txt 中的包名列表。"""
    failed_file = repo / ".test-logs" / "FAILED.txt"
    if not failed_file.exists():
        return []
    return [
        line.strip().split(" ")[0]
        for line in failed_file.read_text().splitlines()
        if line.strip()
    ]


def test_all_packages_pass_exits_zero():
    """全部包成功时退出 0。"""
    print("▶ all packages pass → exit 0")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        repo = build_fake_repo(tmp, ["AlphaKit", "BetaPlugin"])
        stub_dir = build_stub(tmp)
        control = tmp / "control"
        control.mkdir()

        code, output = run_script(repo, stub_dir, control)
        assert code == 0, f"expected exit 0, got {code}\n{output}"
        assert failed_packages(repo) == [], (
            f"expected empty FAILED.txt, got {failed_packages(repo)}"
        )
        assert "总包数: 2" in output, f"expected summary in output\n{output}"
    print("  ✅ all pass exits 0")


def test_failing_package_exits_nonzero():
    """任一包测试失败时脚本必须非零退出，且 FAILED.txt 含失败包。"""
    print("▶ one package fails → nonzero exit")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        repo = build_fake_repo(tmp, ["AlphaKit", "BetaPlugin"])
        stub_dir = build_stub(tmp)
        control = tmp / "control"
        control.mkdir()
        (control / "BetaPlugin.rc").write_text("3\n")

        code, output = run_script(repo, stub_dir, control)
        assert code != 0, f"expected nonzero exit, got {code}\n{output}"
        assert failed_packages(repo) == ["BetaPlugin"], (
            f"expected FAILED.txt to contain BetaPlugin, got {failed_packages(repo)}"
        )
        assert "BetaPlugin" in output, f"expected failure listed in summary\n{output}"
    print("  ✅ failing package exits nonzero")


def test_missing_rc_file_counts_as_failure():
    """rc 文件缺失必须算失败，不能当成跳过。"""
    print("▶ missing rc file → nonzero exit")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        repo = build_fake_repo(tmp, ["AlphaKit", "BetaPlugin"])
        stub_dir = build_stub(tmp)
        control = tmp / "control"
        control.mkdir()
        (control / "BetaPlugin.kill").write_text("1\n")

        code, output = run_script(repo, stub_dir, control)
        assert code != 0, f"expected nonzero exit, got {code}\n{output}"
        assert "BetaPlugin" in failed_packages(repo), (
            f"expected FAILED.txt to contain BetaPlugin, got {failed_packages(repo)}"
        )
    print("  ✅ missing rc counts as failure")


def test_multiple_failures_all_listed():
    """多个包失败时全部出现在 FAILED.txt。"""
    print("▶ multiple failures → all listed")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        repo = build_fake_repo(tmp, ["AlphaKit", "BetaPlugin", "GammaKit"])
        stub_dir = build_stub(tmp)
        control = tmp / "control"
        control.mkdir()
        (control / "AlphaKit.rc").write_text("1\n")
        (control / "GammaKit.rc").write_text("2\n")

        code, output = run_script(repo, stub_dir, control)
        assert code != 0, f"expected nonzero exit, got {code}\n{output}"
        listed = set(failed_packages(repo))
        assert listed == {"AlphaKit", "GammaKit"}, (
            f"expected AlphaKit and GammaKit in FAILED.txt, got {listed}"
        )
    print("  ✅ all failures listed")


def test_summary_still_printed():
    """汇总摘要必须仍然打印，便于 CI 日志阅读。"""
    print("▶ summary is printed on failure")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        repo = build_fake_repo(tmp, ["AlphaKit"])
        stub_dir = build_stub(tmp)
        control = tmp / "control"
        control.mkdir()
        (control / "AlphaKit.rc").write_text("1\n")

        code, output = run_script(repo, stub_dir, control)
        assert code != 0
        assert "===== 测试汇总 =====" in output, f"expected summary header\n{output}"
        assert "失败列表" in output, f"expected failure list header\n{output}"
    print("  ✅ summary printed")


def main():
    tests = [
        test_all_packages_pass_exits_zero,
        test_failing_package_exits_nonzero,
        test_missing_rc_file_counts_as_failure,
        test_multiple_failures_all_listed,
        test_summary_still_printed,
    ]

    failed = 0
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"  ❌ {test.__name__}: {e}")
            failed += 1

    print()
    if failed == 0:
        print(f"✅ test-run-all-package-tests.py: {len(tests)} tests passed")
        return 0
    print(f"❌ test-run-all-package-tests.py: {failed} of {len(tests)} tests failed")
    return 1


if __name__ == "__main__":
    sys.exit(main())
