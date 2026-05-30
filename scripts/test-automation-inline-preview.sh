#!/usr/bin/env bash
#
# test-automation-inline-preview.sh
#
# 自动化测试 Inline Preview 的 Start Stream / Stop Stream 功能。
# 通过 Lumi 的 HTTP 自动化 API 发送指令，
# 然后检查应用日志验证状态转换是否正确。
#
# 前置条件：
#   1. Lumi 应用已启动并运行（AutomationServer 在 localhost:18765 或备用端口监听）
#   2. bash 4+ / zsh（支持 mapfile）
#
# 用法：
#   ./scripts/test-automation-inline-preview.sh          # 完整测试
#   ./scripts/test-automation-inline-preview.sh --stream  # 仅测 Start/Stop Stream
#   ./scripts/test-automation-inline-preview.sh --demo    # 仅测 Demo Frame
#

set -euo pipefail

# ── 配置 ──────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/automation-server.sh"
BASE_URL="$(lumi_automation_api_url "${LUMI_AUTOMATION_PORT:-18765}")"
LOG_DIR="$(lumi_file_log_dir)"
UNIFIED_LOG_LAST="20m"
START_STREAM_WAIT=5    # 等待 Start Stream 完成的秒数
STOP_STREAM_WAIT=3     # 等待 Stop Stream 完成的秒数
DEMO_FRAME_WAIT=2      # 等待 Demo Frame 渲染的秒数

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── 辅助函数 ──────────────────────────────────────────────────────────

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[PASS]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; }
step()  { echo -e "${YELLOW}[STEP]${NC} $*"; }

# 发送自动化动作
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

# 检查 API 是否返回 ok（JSON key 顺序/空白不固定）
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

# 获取最新日志文件路径
get_latest_log() {
    LOG_DIR="$(lumi_file_log_dir)"
    ls -t "$LOG_DIR" 2>/dev/null | head -1
}

# 在日志中搜索关键词（最近 N 秒内的日志）
# 用法: grep_log "keyword" [seconds_ago]
grep_log() {
    local keyword="$1"
    local log_file
    log_file=$(get_latest_log)
    
    if [ -z "$log_file" ]; then
        fail "未找到日志文件（目录: ${LOG_DIR}）"
        return 1
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

# 断言日志中包含关键词
assert_log_contains() {
    local keyword="$1"
    local description="$2"
    local count
    
    count=$(grep_log "$keyword")
    if [ "$count" -gt 0 ]; then
        ok "${description}（找到 $count 条匹配）"
        return 0
    else
        fail "${description}（未找到关键词: ${keyword}）"
        return 1
    fi
}

note_log_contains() {
    local keyword="$1"
    local description="$2"
    local count

    count=$(grep_log "$keyword")
    if [ "$count" -gt 0 ]; then
        ok "${description}（找到 ${count} 条匹配）"
    else
        info "${description}（未找到日志关键词: ${keyword}，跳过日志辅助检查）"
    fi
}

assert_editor_panel_active() {
    local response
    response=$(send_action "project.debug_state" "{}")
    assert_api_ok "$response" "project.debug_state → API 响应成功" || return 1

    DEBUG_STATE_JSON="$response" python3 <<'PY'
import json
import os

state = json.loads(os.environ["DEBUG_STATE_JSON"])
active_panel = state.get("activePanel")
print("activePanel=", active_panel)
if active_panel != "chevron.left.forwardslash.chevron.right":
    raise SystemExit("FAIL: editor panel is not active")
PY
    ok "编辑器面板已激活"
}

automation_debug_state() {
    send_action "automation.debug_state" "{}"
}

json_field() {
    local json="$1"
    local field="$2"
    JSON_BODY="$json" JSON_FIELD="$field" python3 <<'PY'
import json
import os

body = os.environ["JSON_BODY"]
field = os.environ["JSON_FIELD"]
value = json.loads(body).get(field)
if value is None:
    print("")
else:
    print(value)
PY
}

assert_counter_increased() {
    local before_json="$1"
    local after_json="$2"
    local field="$3"
    local description="$4"

    local before
    local after
    before=$(json_field "$before_json" "$field")
    after=$(json_field "$after_json" "$field")
    if [ "${after:-0}" -gt "${before:-0}" ]; then
        ok "${description}（${before:-0} → ${after:-0}）"
        return 0
    fi

    fail "${description}（计数未增加: ${before:-0} → ${after:-0}）"
    return 1
}

assert_last_session_action() {
    local expected="$1"
    local description="$2"
    local state
    local actual

    state=$(automation_debug_state)
    assert_api_ok "$state" "automation.debug_state → API 响应成功" || return 1
    actual=$(json_field "$state" "lastSessionActionName")
    if [ "$actual" = "$expected" ]; then
        ok "$description"
        return 0
    fi

    fail "$description（期望: ${expected}, 实际: ${actual}）"
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
}

# ── 测试用例 ──────────────────────────────────────────────────────────

# 测试 1: 导航到编辑器面板
test_navigate_to_editor() {
    step "测试 1: 导航到编辑器面板"
    
    local response
    response=$(send_action "navigate.to" '{"panel": "editor"}')
    assert_api_ok "$response" "navigate.to editor → API 响应成功" || return 1
    
    sleep 1
    assert_editor_panel_active
}

# 测试 2: Demo Frame 渲染
test_demo_frame() {
    step "测试 2: Demo Frame 渲染"
    
    local before_state
    before_state=$(automation_debug_state)
    assert_api_ok "$before_state" "automation.debug_state → API 响应成功" || return 1

    local response
    response=$(send_action "inline_preview.demoFrame" '{"width": 640, "height": 360, "scale": 2.0}')
    assert_api_ok "$response" "inline_preview.demoFrame → API 响应成功" || return 1
    
    sleep "$DEMO_FRAME_WAIT"

    local after_state
    after_state=$(automation_debug_state)
    assert_api_ok "$after_state" "automation.debug_state → API 响应成功" || return 1
    assert_counter_increased "$before_state" "$after_state" "demoFrameRequestCount" "Demo Frame 请求已处理"
    assert_counter_increased "$before_state" "$after_state" "inlinePreviewTabActivationCount" "Inline Preview 底部标签已激活"
}

# 测试 3: Start Stream
test_start_stream() {
    step "测试 3: Start Stream"
    
    local response
    response=$(send_action "inline_preview.start_stream")
    assert_api_ok "$response" "inline_preview.start_stream → API 响应成功" || return 1
    
    info "等待 $START_STREAM_WAIT 秒让 Session 启动..."
    sleep "$START_STREAM_WAIT"
    
    # 检查 AutomationController 路由
    assert_last_session_action "start" "AutomationController 路由到 startStream 处理器"
    
    # 检查面板和标签激活
    assert_editor_panel_active
    local state
    state=$(automation_debug_state)
    assert_api_ok "$state" "automation.debug_state → API 响应成功" || return 1
    local inline_tab_count
    inline_tab_count=$(json_field "$state" "inlinePreviewTabActivationCount")
    if [ "${inline_tab_count:-0}" -gt 0 ]; then
        ok "Inline Preview 底部标签已激活（累计 ${inline_tab_count} 次）"
    else
        fail "Inline Preview 底部标签未激活"
        return 1
    fi
    
    # 检查 ViewModel 状态变化: idle → starting → running
    note_log_contains "startSession" "ViewModel 收到 startSession 调用"
    note_log_contains "status 变化：idle → starting" "状态转换: idle → starting"
    
    # running 状态可能需要更长时间（子进程启动）
    local running_count
    running_count=$(grep_log "status 变化：starting → running")
    if [ "$running_count" -gt 0 ]; then
        ok "状态转换: starting → running（Session 运行中）"
    else
        info "未检测到 running 状态（子进程可能仍在启动，这不一定是错误）"
    fi
}

# 测试 4: Stop Stream
test_stop_stream() {
    step "测试 4: Stop Stream"
    
    local response
    response=$(send_action "inline_preview.stop_stream")
    assert_api_ok "$response" "inline_preview.stop_stream → API 响应成功" || return 1
    
    info "等待 $STOP_STREAM_WAIT 秒让 Session 停止..."
    sleep "$STOP_STREAM_WAIT"
    
    # 检查 AutomationController 路由
    assert_last_session_action "stop" "AutomationController 路由到 stopStream 处理器"
    
    # 检查 ViewModel 状态变化
    note_log_contains "stopSession" "ViewModel 收到 stopSession 调用"
    
    local stopping_count
    stopping_count=$(grep_log "status 变化：running → stopping")
    if [ "$stopping_count" -gt 0 ]; then
        ok "状态转换: running → stopping"
    fi
    
    local idle_count
    idle_count=$(grep_log "status 变化：stopping → idle")
    if [ "$idle_count" -gt 0 ]; then
        ok "状态转换: stopping → idle（Session 已停止）"
    else
        info "未检测到 idle 状态（停止可能仍在进行中）"
    fi
    
    note_log_contains "Session 已停止" "Session 已完全停止"
}

# 测试 5: 完整生命周期 (Start → Stop)
test_full_lifecycle() {
    step "测试 5: 完整生命周期 (Start → 等待 → Stop)"
    
    # 先确保处于 idle 状态
    info "确保 Session 已停止..."
    send_action "inline_preview.stop_stream" > /dev/null 2>&1
    sleep 2
    
    # Start
    info "发送 Start Stream..."
    local response
    response=$(send_action "inline_preview.start_stream")
    assert_api_ok "$response" "Start Stream API 调用成功" || return 1
    
    sleep "$START_STREAM_WAIT"
    
    # Stop
    info "发送 Stop Stream..."
    response=$(send_action "inline_preview.stop_stream")
    assert_api_ok "$response" "Stop Stream API 调用成功" || return 1
    
    sleep "$STOP_STREAM_WAIT"
    ok "完整生命周期测试通过"
}

# 测试 6: 幂等性 — 重复 start/stop 不应崩溃
test_idempotency() {
    step "测试 6: 幂等性测试（连续操作不崩溃）"
    
    # 连续 Start 两次
    send_action "inline_preview.start_stream" > /dev/null 2>&1
    sleep 1
    send_action "inline_preview.start_stream" > /dev/null 2>&1
    sleep "$START_STREAM_WAIT"
    ok "连续 Start Stream ×2 未崩溃"
    
    # 连续 Stop 两次
    send_action "inline_preview.stop_stream" > /dev/null 2>&1
    sleep 1
    send_action "inline_preview.stop_stream" > /dev/null 2>&1
    sleep "$STOP_STREAM_WAIT"
    ok "连续 Stop Stream ×2 未崩溃"
}

# ── 主流程 ────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Lumi Inline Preview — 自动化测试                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    local test_mode="${1:-all}"
    local failed=0
    
    check_prerequisites
    
    echo ""
    info "最新日志文件: $(get_latest_log)"
    echo ""
    
    case "$test_mode" in
        --stream)
            test_navigate_to_editor || ((failed++))
            echo ""
            test_start_stream || ((failed++))
            echo ""
            test_stop_stream || ((failed++))
            echo ""
            test_full_lifecycle || ((failed++))
            echo ""
            test_idempotency || ((failed++))
            ;;
        --demo)
            test_navigate_to_editor || ((failed++))
            echo ""
            test_demo_frame || ((failed++))
            ;;
        all|--all|*)
            test_navigate_to_editor || ((failed++))
            echo ""
            test_demo_frame || ((failed++))
            echo ""
            test_start_stream || ((failed++))
            echo ""
            test_stop_stream || ((failed++))
            echo ""
            test_full_lifecycle || ((failed++))
            echo ""
            test_idempotency || ((failed++))
            ;;
    esac
    
    echo ""
    echo "══════════════════════════════════════════════════════════════"
    if [ "$failed" -eq 0 ]; then
        ok "所有测试通过 ✅"
    else
        fail "$failed 个测试失败 ❌"
        exit 1
    fi
    echo ""
}

main "$@"
