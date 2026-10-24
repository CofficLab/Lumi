#!/usr/bin/env bash
# ============================================================
# check-remote-plugin-package-names.sh
#
# 远程插件包（SPM 远程依赖里的插件包）必须以 `LumiPlugin` 开头。
#
# 为什么需要它
# ------------
# Xcode 的包依赖列表显示的是各上游仓库 Package.swift 里声明的
# `Package(name:)`，不是仓库名。所以仓库叫 `LumiPluginActivityBar`，
# 但 manifest 写成 `name: "PluginActivityBar"` 时，Xcode 里显示的就是
# `PluginActivityBar` —— 用户看到的名字里 Lumi 前缀就丢了。
#
# 本仓库对 9 个远程插件包统一要求：manifest 的 `name:` 必须是
# `LumiPluginXXX`，与仓库名一致（`LumiPluginBookletMaker` 等已合规）。
# 注意只约束**包名**；product / target 仍然是 `PluginXXX`
# （例如 LumiPluginStorage 的包名带前缀，product 叫 PluginStorage），
# 消费方 `.product(name:package:)` 里的 `package:` 参数按 URL basename
# 匹配，改包名不影响既有引用。
#
# 用法：
#   bash Scripts/check-remote-plugin-package-names.sh
#   bash Scripts/check-remote-plugin-package-names.sh --online   # 额外拉远端 manifest 校验
# ============================================================

set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 远程插件包清单：仓库名 -> 期望的 manifest 包名
# 注意：manifest 包名与仓库名一致（远程插件包统一带 Lumi 前缀）。
# 用 "repo:expected" 列表而非关联数组 —— macOS 自带 bash 3.2 不支持关联数组。
EXPECTED_PACKAGE_PAIRS=(
  "LumiPluginActivityBar:LumiPluginActivityBar"
  "LumiPluginBookletMaker:LumiPluginBookletMaker"
  "LumiPluginCommand:LumiPluginCommand"
  "LumiPluginIdleTime:LumiPluginIdleTime"
  "LumiPluginSettingView:LumiPluginSettingView"
  "LumiPluginStorage:LumiPluginStorage"
  "LumiPluginThemeManager:LumiPluginThemeManager"
  "LumiPluginThemePack:LumiPluginThemePack"
  "LumiPluginToast:LumiPluginToast"
)

expected_name_for() {
  local repo_name="$1" pair repo expected
  for pair in "${EXPECTED_PACKAGE_PAIRS[@]}"; do
    repo="${pair%%:*}"
    expected="${pair##*:}"
    if [[ "$repo" == "$repo_name" ]]; then
      printf '%s' "$expected"
      return 0
    fi
  done
  return 1
}

online=0
if [[ "${1:-}" == "--online" ]]; then
  online=1
fi

failures=0

# ---------------------------------------------------------------------------
# 1. 本地检出的上游 manifest：manifest 的 name: 必须等于仓库名
# ---------------------------------------------------------------------------
checkout_roots=(
  "$workspace_root/SourcePackages/checkouts"
)
for pkg_root in "$workspace_root"/Packages/*/.build/checkouts; do
  [[ -d "$pkg_root" ]] && checkout_roots+=("$pkg_root")
done

for pair in "${EXPECTED_PACKAGE_PAIRS[@]}"; do
  repo_name="${pair%%:*}"
  expected="${pair##*:}"
  manifest=""
  for root in "${checkout_roots[@]}"; do
    candidate="$root/$repo_name/Package.swift"
    if [[ -f "$candidate" ]]; then
      manifest="$candidate"
      break
    fi
  done

  if [[ -z "$manifest" ]]; then
    # 本地没有检出：跳过（--online 模式会去远端查）
    continue
  fi

  declared="$(sed -nE 's/^[[:space:]]*name:[[:space:]]*"([^"]+)",[[:space:]]*$/\1/p' "$manifest" | head -n 1)"
  if [[ -z "$declared" ]]; then
    printf '无法从 manifest 读取包名: %s\n' "$manifest"
    failures=1
    continue
  fi

  if [[ "$declared" != "$expected" ]]; then
    printf '远程插件包 %s 的 manifest 包名应为 %s，实际为 %s\n' "$repo_name" "$expected" "$declared"
    printf '    manifest: %s\n' "$manifest"
    failures=1
  fi
done

# ---------------------------------------------------------------------------
# 2. 消费方引用：package: 参数必须用仓库名（带 Lumi 前缀）
# ---------------------------------------------------------------------------
# 消费方写 `.product(name: "PluginThemePack", package: "LumiPluginThemePack")`，
# 这里的 package: 按 URL basename 匹配，必须等于仓库名。
while IFS= read -r manifest_path; do
  if ! rg -q --pcre2 '\.package\(\s*url:\s*"https://github\.com/CofficLab/(LumiPlugin[A-Za-z0-9]+)\.git"' "$manifest_path"; then
    continue
  fi
  while IFS= read -r repo_name; do
    expected="$(expected_name_for "$repo_name" || true)"
    if [[ -z "$expected" ]]; then
      printf '未知远程插件包，未登记在守卫清单中: %s (%s)\n' "$repo_name" "$manifest_path"
      failures=1
      continue
    fi
    if ! rg -q --fixed-strings "package: \"$expected\"" "$manifest_path"; then
      printf '消费方 %s 引用 %s 时 package: 必须写成 "%s"\n' "$manifest_path" "$repo_name" "$expected"
      failures=1
    fi
  done < <(rg -o --no-filename --pcre2 --replace '$1' 'https://github\.com/CofficLab/(LumiPlugin[A-Za-z0-9]+)\.git' "$manifest_path" | sort -u)
done < <(rg --files --glob 'Package.swift' --glob '!**/.build/**' "$workspace_root")

# ---------------------------------------------------------------------------
# 3. --online：拉远端 manifest 校验（CI / 手动核对用）
# ---------------------------------------------------------------------------
if [[ "$online" -eq 1 ]]; then
  for pair in "${EXPECTED_PACKAGE_PAIRS[@]}"; do
    repo_name="${pair%%:*}"
    expected="${pair##*:}"
    manifest_url="https://raw.githubusercontent.com/CofficLab/$repo_name/main/Package.swift"
    body="$(curl -fsSL "$manifest_url" 2>/dev/null || true)"
    if [[ -z "$body" ]]; then
      printf '无法拉取远端 manifest: %s\n' "$manifest_url"
      failures=1
      continue
    fi
    declared="$(printf '%s\n' "$body" | sed -nE 's/^[[:space:]]*name:[[:space:]]*"([^"]+)",[[:space:]]*$/\1/p' | head -n 1)"
    if [[ "$declared" != "$expected" ]]; then
      printf '远程插件包 %s 的 manifest 包名应为 %s，实际为 %s\n' "$repo_name" "$expected" "$declared"
      failures=1
    fi
  done
fi

if [[ "$failures" -ne 0 ]]; then
  printf '\n[FAIL] 远程插件包名未统一为 LumiPluginXXX\n'
  exit 1
fi

printf '[OK] %d 个远程插件包的包名均符合 LumiPluginXXX 规范\n' "${#EXPECTED_PACKAGE_PAIRS[@]}"
