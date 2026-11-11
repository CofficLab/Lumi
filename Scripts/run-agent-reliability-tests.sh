#!/bin/bash
# Agent 可靠性分组测试入口。
#
# 用途：把全仓 200+ 个包的 `swift test` 收敛成一组与 Agent 核心链路相关的
# 可重复门禁，供 CI 在 PR 上执行。分组对应
# docs/plans/2026-11-07-agent-test-and-architecture-governance.md 的
# contracts / runtime / integration 三层。
#
# 用法：
#   Scripts/run-agent-reliability-tests.sh contracts
#   Scripts/run-agent-reliability-tests.sh runtime
#   Scripts/run-agent-reliability-tests.sh integration
#   Scripts/run-agent-reliability-tests.sh all
#
# 语义：
#   - 任一包测试失败 → 本组非零退出
#   - 一个包失败不中断整组：跑完整组后统一汇总，一次暴露全部问题
#   - 本地不存在的包（远程 SPM 包）或没有 Tests 目录的包 → 打印原因并跳过，
#     不计为失败，但会在日志里显式列出，避免"看起来跑过了"
#   - 每个包的完整输出写入 .test-logs/agent-reliability/<group>/<pkg>.log

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/.test-logs/agent-reliability"
GROUP="${1:-}"

CONTRACTS=(
  ProviderDiagnostics
  KitAgentTool
  KitLLM
  ProviderMessage
  ProviderMessageSender
  ProviderAgentLoop
  ProviderToolManager
)

RUNTIME=(
  PluginMessageManager
  PluginMessageSender
  ProviderMessageStreaming
  ProviderLLMManager
  PluginAgentLoop
  PluginToolManager
  PluginConversationInput
  PluginConversationResume
)

INTEGRATION=(
  KitMCP
  PluginMCP
  PluginNetworkManager
  PluginFileLog
  PluginMessageRenderer
  PluginConversationExport
  FactoryLumi
)

usage() {
  echo "用法: $0 {contracts|runtime|integration|all}" >&2
  echo "" >&2
  echo "  contracts   纯值语义 / 契约层：Provider*、Kit*"
  echo "  runtime     运行时实现层：Plugin*"
  echo "  integration 集成装配层：MCP、渲染、导出、FactoryLumi"
  echo "  all         依次执行以上三组"
}

case "$GROUP" in
  contracts|runtime|integration|all) ;;
  *)
    usage
    exit 2
    ;;
esac

mkdir -p "$OUT"

# 取分组对应的包列表。不用间接展开（${!name}）以兼容 macOS 自带的 bash 3.2。
group_packages_for() {
  case "$1" in
    contracts) printf '%s\n' "${CONTRACTS[@]}" ;;
    runtime) printf '%s\n' "${RUNTIME[@]}" ;;
    integration) printf '%s\n' "${INTEGRATION[@]}" ;;
  esac
}

run_group() {
  local group="$1"
  shift

  local log_dir="$OUT/$group"
  mkdir -p "$log_dir"

  echo "=============================================="
  echo "▶ 分组: $group （$# 个包）"
  echo "=============================================="

  local failed=0
  local skipped=0
  local passed=0
  local pkg pkg_dir log_file
  local failed_packages=()

  for pkg in "$@"; do
    pkg_dir="$ROOT/Packages/$pkg"
    log_file="$log_dir/$pkg.log"

    if [ ! -f "$pkg_dir/Package.swift" ]; then
      echo "  ⏭  $pkg — 本地无该包源码（远程 SPM 依赖），跳过"
      skipped=$((skipped + 1))
      continue
    fi

    if [ ! -d "$pkg_dir/Tests" ]; then
      echo "  ⏭  $pkg — 无 Tests 目录，跳过"
      skipped=$((skipped + 1))
      continue
    fi

    echo "  ▶ $pkg"
    if swift test --package-path "$pkg_dir" > "$log_file" 2>&1; then
      echo "    ✅ 通过（日志: ${log_file#$ROOT/}）"
      passed=$((passed + 1))
    else
      echo "    ❌ 失败（日志: ${log_file#$ROOT/}）"
      failed=$((failed + 1))
      failed_packages+=("$pkg")
    fi
  done

  echo ""
  if [ "$failed" -ne 0 ]; then
    echo "  分组 $group 失败 — 通过: $passed / 失败: $failed / 跳过: $skipped"
    echo "  失败包: ${failed_packages[*]}"
    for pkg in "${failed_packages[@]}"; do
      echo ""
      echo "  ── $pkg 失败输出尾部 ──"
      tail -n 30 "$log_dir/$pkg.log" | sed 's/^/     /'
    done
    return 1
  fi

  echo "  分组 $group 完成 — 通过: $passed / 失败: $failed / 跳过: $skipped"
  return 0
}

overall=0

if [ "$GROUP" = "all" ]; then
  for g in contracts runtime integration; do
    group_packages=()
    while IFS= read -r line; do
      group_packages+=("$line")
    done < <(group_packages_for "$g")
    if ! run_group "$g" "${group_packages[@]}"; then
      overall=1
    fi
  done
else
  group_packages=()
  while IFS= read -r line; do
    group_packages+=("$line")
  done < <(group_packages_for "$GROUP")
  run_group "$GROUP" "${group_packages[@]}" || overall=1
fi

exit $overall
