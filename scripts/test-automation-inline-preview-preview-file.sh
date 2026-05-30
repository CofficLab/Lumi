#!/usr/bin/env bash
#
# test-automation-inline-preview-preview-file.sh
#
# 自动化测试：打开 Swift 文件 → 自动编译 #Preview → Inline Preview 渲染。
# 通过 Lumi 的 HTTP 自动化 API 发送指令，
# 然后检查应用日志验证整个链路是否正确工作。
#
# 测试场景：打开 AppAvatar.swift（含 #Preview），验证 Inline Preview
# 自动编译并加载用户的预览视图。
#
# 前置条件：
#   1. Lumi 应用已启动并运行（AutomationServer 在 localhost:18765 或备用端口监听）
#   2. bash 4+ / zsh
#
# 用法：
#   ./scripts/test-automation-inline-preview-preview-file.sh
#

set -uo pipefail

# ── 配置 ──────────────────────────────────────────────────────────────

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"
source "$SCRIPT_DIR/lib/automation-server.sh"
BASE_URL="$(lumi_automation_api_url "${LUMI_AUTOMATION_PORT:-18765}")"
DEBUG_LOG_DIR="$HOME/Library/Application Support/com.coffic.lumi/logs_debug_v2"
PRODUCTION_LOG_DIR="$HOME/Library/Application Support/com.coffic.lumi/logs_production_v2"
if find "$DEBUG_LOG_DIR" -maxdepth 1 -type f -name '*.log' -print -quit 2>/dev/null | grep -q .; then
    LOG_DIR="$DEBUG_LOG_DIR"
else
    LOG_DIR="$PRODUCTION_LOG_DIR"
fi
UNIFIED_LOG_LAST="20m"

# 测试文件（含 #Preview 的自包含 SwiftUI 视图）
TEST_FILE="$ROOT_DIR/Packages/LumiUI/Sources/LumiUI/Components/AppAvatar.swift"

# 各步骤等待时间
NAVIGATE_WAIT=2
OPEN_FILE_WAIT=3
START_STREAM_WAIT=8       # 子进程启动 + 自动编译 + 加载
BUILD_VERIFY_WAIT=5       # 等待编译完成
STOP_STREAM_WAIT=3

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── 辅助函数 ──────────────────────────────────────────────────────────

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[PASS]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; }
step()  { echo -e "${YELLOW}[STEP]${NC} $*"; }

send_action() {
    local action="$1"
    local payload="${2:-}"

    if [ -n "$payload" ]; then
        curl -s -X POST "$BASE_URL" \
            -H "Content-Type: application/json" \
            -d "{\"action\": \"$action\", \"payload\": $payload}"
    else
        curl -s -X POST "$BASE_URL" \
            -H "Content-Type: application/json" \
            -d "{\"action\": \"$action\"}"
    fi
}

# 检查 API 是否返回 ok（JSON key 顺序不固定，用宽松匹配）
api_ok() {
    echo "$1" | grep -qE '"status"\s*:\s*"ok"'
}

# 断言 API 返回成功
assert_api_ok() {
    local response="$1"
    local description="$2"

    if api_ok "$response"; then
        ok "$description"
        return 0
    else
        fail "${description}（响应: ${response}）"
        return 1
    fi
}

automation_debug_state() {
    send_action "automation.debug_state" "{}"
}

json_value() {
    local json="$1"
    local key="$2"

    JSON_INPUT="$json" /usr/bin/python3 - "$key" <<'PY'
import json
import os
import sys

key = sys.argv[1]
try:
    data = json.loads(os.environ.get("JSON_INPUT", "{}"))
except Exception:
    print("")
    raise SystemExit(0)

value = data
for part in key.split("."):
    if isinstance(value, dict):
        value = value.get(part, "")
    else:
        value = ""
        break

if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

state_string() {
    json_value "$(automation_debug_state)" "$1"
}

state_int() {
    local value
    value=$(state_string "$1")
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo "0"
    fi
}

assert_state_int_increased() {
    local key="$1"
    local before="$2"
    local description="$3"
    local after

    after=$(state_int "$key")
    if [ "$after" -gt "$before" ]; then
        ok "${description}（${before} → ${after}）"
        return 0
    fi

    fail "${description}（${key} 未递增，当前 ${after}）"
    return 1
}

assert_state_string_equals() {
    local key="$1"
    local expected="$2"
    local description="$3"
    local actual

    actual=$(state_string "$key")
    if [ "$actual" = "$expected" ]; then
        ok "$description"
        return 0
    fi

    fail "${description}（${key}=${actual}，期望 ${expected}）"
    return 1
}

assert_state_bool_true() {
    local key="$1"
    local description="$2"
    local actual

    actual=$(state_string "$key")
    if [ "$actual" = "true" ]; then
        ok "$description"
        return 0
    fi

    fail "${description}（${key}=${actual}）"
    return 1
}

wait_for_state_string() {
    local key="$1"
    local expected="$2"
    local description="$3"
    local max_wait="${4:-10}"
    local elapsed=0

    while [ "$elapsed" -lt "$max_wait" ]; do
        local actual
        actual=$(state_string "$key")
        if [ "$actual" = "$expected" ]; then
            ok "${description}（等待 ${elapsed}s）"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    fail "${description}（等待 ${max_wait}s 后 $key=$(state_string "$key")）"
    return 1
}

wait_for_preview_entry_loaded() {
    local description="$1"
    local max_wait="${2:-20}"
    local elapsed=0

    while [ "$elapsed" -lt "$max_wait" ]; do
        local entry_status
        entry_status=$(state_string "previewEntryStatus")
        case "$entry_status" in
            loaded\(*)
                ok "${description}（等待 ${elapsed}s，${entry_status}）"
                return 0
                ;;
            failed\(*)
                fail "${description}（${entry_status}，日志: $(state_string "previewLastBuildLogPath")）"
                return 1
                ;;
        esac
        sleep 1
        elapsed=$((elapsed + 1))
    done

    fail "${description}（等待 ${max_wait}s 后 previewEntryStatus=$(state_string "previewEntryStatus")）"
    return 1
}

wait_for_state_int_greater_than() {
    local key="$1"
    local before="$2"
    local description="$3"
    local max_wait="${4:-10}"
    local elapsed=0

    while [ "$elapsed" -lt "$max_wait" ]; do
        local current
        current=$(state_int "$key")
        if [ "$current" -gt "$before" ]; then
            ok "${description}（${before} → ${current}，等待 ${elapsed}s）"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    fail "${description}（等待 ${max_wait}s 后 $key=$(state_int "$key")）"
    return 1
}

get_latest_log() {
    ls -t "$LOG_DIR" 2>/dev/null | head -1
}

# 在最新日志中搜索关键词，返回匹配行数
grep_log_count() {
    local keyword="$1"
    local log_file
    log_file=$(get_latest_log)

    if [ -z "$log_file" ]; then
        echo "0"
        return
    fi

    local count
    count=$(grep -c "$keyword" "$LOG_DIR/$log_file" 2>/dev/null || true)
    if [ "${count:-0}" -gt 0 ]; then
        echo "$count"
        return
    fi

    count=$(/usr/bin/log show \
        --predicate 'subsystem == "com.coffic.lumi"' \
        --last "$UNIFIED_LOG_LAST" \
        --style compact 2>/dev/null | grep -c "$keyword" || true)
    echo "${count:-0}"
}

# 断言日志包含关键词（不因 set -e 而终止）
assert_log_contains() {
    local keyword="$1"
    local description="$2"
    local count

    count=$(grep_log_count "$keyword")
    if [ "$count" -gt 0 ]; then
        ok "${description}（找到 ${count} 条匹配）"
        return 0
    else
        fail "${description}（未找到关键词: ${keyword}）"
        return 1
    fi
}

# 断言日志在等待后出现关键词（轮询方式，不因 set -e 而终止）
wait_for_log() {
    local keyword="$1"
    local description="$2"
    local max_wait="${3:-10}"
    local elapsed=0

    while [ "$elapsed" -lt "$max_wait" ]; do
        local count
        count=$(grep_log_count "$keyword")
        if [ "$count" -gt 0 ]; then
            ok "${description}（等待 ${elapsed}s，找到 ${count} 条匹配）"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    fail "${description}（等待 ${max_wait}s 后仍未出现关键词: ${keyword}）"
    return 1
}

# ── 前置检查 ──────────────────────────────────────────────────────────

check_prerequisites() {
    info "检查前置条件..."

    if ! BASE_URL="$(lumi_resolve_automation_base_url)"; then
        fail "无法连接到 Lumi 自动化服务器（已检查端口: $(lumi_automation_candidate_ports | tr '\n' ' ')）"
        fail "请确保 Lumi 应用已启动"
        exit 1
    fi
    ok "Lumi 自动化服务器可达: $BASE_URL"

    # 检查日志目录
    if [ ! -d "$LOG_DIR" ]; then
        fail "日志目录不存在: $LOG_DIR"
        exit 1
    fi
    ok "日志目录存在"

    # 检查测试文件
    if [ ! -f "$TEST_FILE" ]; then
        fail "测试文件不存在: $TEST_FILE"
        exit 1
    fi
    ok "测试文件存在: $(basename "$TEST_FILE")"
}

# ── 测试用例 ──────────────────────────────────────────────────────────

# 测试 1: 导航到编辑器面板
test_navigate_to_editor() {
    step "测试 1: 导航到编辑器面板"

    local before_count
    before_count=$(state_int "editorPanelActivationCount")

    local response
    response=$(send_action "navigate.to" '{"panel": "editor"}')
    assert_api_ok "$response" "navigate.to editor → API 响应成功" || return 1

    sleep "$NAVIGATE_WAIT"
    assert_state_int_increased "editorPanelActivationCount" "$before_count" "编辑器面板已激活"
}

# 测试 2: 激活 Inline Preview 底部面板
test_activate_inline_preview_tab() {
    step "测试 2: 激活 Inline Preview 底部面板"

    local before_tab_count
    local before_demo_count
    before_tab_count=$(state_int "inlinePreviewTabActivationCount")
    before_demo_count=$(state_int "demoFrameRequestCount")

    local response
    response=$(send_action "inline_preview.demoFrame" '{"width": 640, "height": 360, "scale": 2.0}')
    assert_api_ok "$response" "inline_preview.demoFrame → API 响应成功" || return 1

    sleep 2
    assert_state_int_increased "inlinePreviewTabActivationCount" "$before_tab_count" "Inline Preview 底部标签已激活" || return 1
    assert_state_int_increased "demoFrameRequestCount" "$before_demo_count" "Demo 帧已创建"
}

# 测试 3: 打开测试文件
test_open_file() {
    step "测试 3: 打开测试文件 AppAvatar.swift"

    local response
    response=$(send_action "editor.openFile" "{\"path\": \"$TEST_FILE\"}")
    assert_api_ok "$response" "editor.openFile → API 响应成功" || return 1

    sleep "$OPEN_FILE_WAIT"

    assert_state_string_equals "previewActiveFilePath" "$TEST_FILE" "文件已打开" || return 1
    assert_state_string_equals "previewModeName" "swift" "ViewModel 已识别 Swift 预览模式" || return 1
    assert_state_bool_true "previewHasSource" "ViewModel 收到文件源码"
}

# 测试 4: Start Stream + 等待自动编译
test_start_stream_and_auto_build() {
    step "测试 4: Start Stream 并等待自动编译 #Preview"

    local response
    response=$(send_action "inline_preview.start_stream")
    assert_api_ok "$response" "inline_preview.start_stream → API 响应成功" || return 1

    info "等待 $START_STREAM_WAIT 秒让 Session 启动 + 自动编译..."

    # 检查 Session 启动
    wait_for_state_string "previewSessionStatus" "running" "Session 运行中" "$START_STREAM_WAIT" || return 1

    # 检查自动编译流程
    info "等待自动编译 #Preview..."
    wait_for_preview_entry_loaded "预览 dylib 已加载" "$BUILD_VERIFY_WAIT" || return 1
    wait_for_state_int_greater_than "previewLastBuildPreviewCount" 0 "PreviewScanner 已识别 #Preview" 1
}

# 测试 5: 验证帧流产出
test_frame_production() {
    step "测试 5: 验证帧流产出"

    info "等待帧流..."
    wait_for_state_int_greater_than "previewReceivedFrameCount" 0 "收到至少一帧" 6
}

# 测试 6: Stop Stream
test_stop_stream() {
    step "测试 6: Stop Stream"

    local response
    response=$(send_action "inline_preview.stop_stream")
    assert_api_ok "$response" "inline_preview.stop_stream → API 响应成功" || return 1

    sleep "$STOP_STREAM_WAIT"

    assert_state_string_equals "lastSessionActionName" "stop" "ViewModel 收到 stopSession 调用" || return 1
    wait_for_state_string "previewSessionStatus" "idle" "Session 已完全停止" 5
}

# 测试 7: 完整端到端流程（先打开文件 → Start Stream → Auto Build → Stop）
test_full_e2e() {
    step "测试 7: 完整端到端流程（先打开文件，再启动 Stream）"

    # 确保 idle
    send_action "inline_preview.stop_stream" > /dev/null 2>&1
    sleep 2

    # 先打开文件（此时 Stream 未启动，ViewModel 只 stash 文件信息）
    info "先打开测试文件..."
    local response
    response=$(send_action "editor.openFile" "{\"path\": \"$TEST_FILE\"}")
    assert_api_ok "$response" "打开文件 → API 成功" || return 1
    sleep "$OPEN_FILE_WAIT"

    # 再启动 Stream（Session 起来后会 autoBuildIfPossible）
    info "再启动 Stream..."
    response=$(send_action "inline_preview.start_stream")
    assert_api_ok "$response" "Start Stream → API 成功" || return 1

    # 等待完整流程
    info "等待 Session 启动 + 自动编译 + 加载..."
    sleep "$START_STREAM_WAIT"

    wait_for_preview_entry_loaded "端到端：预览已加载并渲染" 10 || return 1
    wait_for_state_int_greater_than "previewReceivedFrameCount" 0 "端到端：帧流已产出" 6 || return 1

    # Stop
    info "停止 Stream..."
    response=$(send_action "inline_preview.stop_stream")
    sleep "$STOP_STREAM_WAIT"
    wait_for_state_string "previewSessionStatus" "idle" "端到端：Stream 已停止" 5
}

# ── 主流程 ────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Inline Preview — #Preview 自动编译渲染 测试                 ║"
    echo "║  测试文件: AppAvatar.swift                                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    local failed=0

    check_prerequisites

    echo ""
    info "最新日志文件: $(get_latest_log)"
    echo ""

    test_navigate_to_editor || ((failed++))
    echo ""

    test_activate_inline_preview_tab || ((failed++))
    echo ""

    test_open_file || ((failed++))
    echo ""

    test_start_stream_and_auto_build || ((failed++))
    echo ""

    test_frame_production || ((failed++))
    echo ""

    test_stop_stream || ((failed++))
    echo ""

    test_full_e2e || ((failed++))
    echo ""

    echo "══════════════════════════════════════════════════════════════"
    if [ "$failed" -eq 0 ]; then
        ok "所有测试通过 ✅  Inline Preview 能自动编译并渲染 #Preview"
    else
        fail "$failed 个测试失败 ❌"
        echo ""
        info "最新日志末尾（供诊断）："
        local log_file
        log_file=$(get_latest_log)
        tail -n 50 "$LOG_DIR/$log_file" 2>/dev/null
        exit 1
    fi
    echo ""
}

main "$@"
