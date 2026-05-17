#!/usr/bin/env bash
#
# test-automation-inline-preview-preview-file.sh
#
# 自动化测试：打开 Swift 文件 → 自动编译 #Preview → Inline Preview 渲染。
# 通过 Lumi 的 HTTP 自动化 API（localhost:18765）发送指令，
# 然后检查应用日志验证整个链路是否正确工作。
#
# 测试场景：打开 AppAvatar.swift（含 #Preview），验证 Inline Preview
# 自动编译并加载用户的预览视图。
#
# 前置条件：
#   1. Lumi 应用已启动并运行（AutomationServer 在 localhost:18765 监听）
#   2. bash 4+ / zsh
#
# 用法：
#   ./scripts/test-automation-inline-preview-preview-file.sh
#

set -uo pipefail

# ── 配置 ──────────────────────────────────────────────────────────────

BASE_URL="http://localhost:18765/api/action"
LOG_DIR="$HOME/Library/Application Support/com.coffic.Lumi/logs_debug_v2"

# 测试文件（含 #Preview 的自包含 SwiftUI 视图）
TEST_FILE="/Users/angel/Code/Coffic/Lumi/Packages/LumiUI/Sources/LumiUI/Components/AppAvatar.swift"

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
        fail "$description（响应: $response）"
        return 1
    fi
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

    grep -c "$keyword" "$LOG_DIR/$log_file" 2>/dev/null || echo "0"
}

# 断言日志包含关键词（不因 set -e 而终止）
assert_log_contains() {
    local keyword="$1"
    local description="$2"
    local count

    count=$(grep_log_count "$keyword")
    if [ "$count" -gt 0 ]; then
        ok "$description（找到 $count 条匹配）"
        return 0
    else
        fail "$description（未找到关键词: $keyword）"
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
            ok "$description（等待 ${elapsed}s，找到 $count 条匹配）"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    fail "$description（等待 ${max_wait}s 后仍未出现关键词: $keyword）"
    return 1
}

# ── 前置检查 ──────────────────────────────────────────────────────────

check_prerequisites() {
    info "检查前置条件..."

    # 检查 Lumi 是否运行
    if ! curl -s --connect-timeout 2 -o /dev/null "$BASE_URL" 2>/dev/null; then
        fail "无法连接到 Lumi 自动化服务器（$BASE_URL）"
        fail "请确保 Lumi 应用已启动"
        exit 1
    fi
    ok "Lumi 自动化服务器可达"

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

    local response
    response=$(send_action "navigate.to" '{"panel": "editor"}')
    assert_api_ok "$response" "navigate.to editor → API 响应成功" || return 1

    sleep "$NAVIGATE_WAIT"
    assert_log_contains "Activated editor panel" "编辑器面板已激活"
}

# 测试 2: 激活 Inline Preview 底部面板
test_activate_inline_preview_tab() {
    step "测试 2: 激活 Inline Preview 底部面板"

    local response
    response=$(send_action "inline_preview.demoFrame" '{"width": 640, "height": 360, "scale": 2.0}')
    assert_api_ok "$response" "inline_preview.demoFrame → API 响应成功" || return 1

    sleep 2
    assert_log_contains "Activated inline preview bottom tab" "Inline Preview 底部标签已激活"
    assert_log_contains "DemoFrame created" "Demo 帧已创建"
}

# 测试 3: 打开测试文件
test_open_file() {
    step "测试 3: 打开测试文件 AppAvatar.swift"

    local response
    response=$(send_action "editor.openFile" "{\"path\": \"$TEST_FILE\"}")
    assert_api_ok "$response" "editor.openFile → API 响应成功" || return 1

    sleep "$OPEN_FILE_WAIT"

    assert_log_contains "File opened: AppAvatar.swift" "文件已打开"
    assert_log_contains "setActiveFile" "ViewModel 收到 setActiveFile 调用"
}

# 测试 4: Start Stream + 等待自动编译
test_start_stream_and_auto_build() {
    step "测试 4: Start Stream 并等待自动编译 #Preview"

    local response
    response=$(send_action "inline_preview.start_stream")
    assert_api_ok "$response" "inline_preview.start_stream → API 响应成功" || return 1

    info "等待 $START_STREAM_WAIT 秒让 Session 启动 + 自动编译..."

    # 检查 Session 启动
    wait_for_log "idle → starting" "Session 启动中" "$START_STREAM_WAIT" || true
    wait_for_log "starting → running" "Session 运行中" 5 || true

    # 检查自动编译流程
    info "等待自动编译 #Preview..."
    wait_for_log "autoBuild" "自动编译流程触发" "$BUILD_VERIFY_WAIT" || true

    # 可能的路径：编译成功 → loaded，或编译失败 → failed/noPreviewFound
    local loaded_count
    loaded_count=$(grep_log_count "entry ·")
    local build_success
    build_success=$(grep_log_count "构建成功")
    local no_preview
    no_preview=$(grep_log_count "未找到")
    local build_failed
    build_failed=$(grep_log_count "swiftc failed")

    if [ "$loaded_count" -gt 0 ]; then
        ok "预览 dylib 已加载（entry loaded）"
    elif [ "$build_success" -gt 0 ]; then
        ok "构建成功，等待加载..."
        sleep 2
        loaded_count=$(grep_log_count "entry ·")
        if [ "$loaded_count" -gt 0 ]; then
            ok "预览 dylib 已加载（entry loaded）"
        else
            info "构建成功但尚未加载，继续等待..."
            sleep 3
            loaded_count=$(grep_log_count "entry ·")
            if [ "$loaded_count" -gt 0 ]; then
                ok "预览 dylib 已加载（延迟确认）"
            else
                fail "构建成功但 dylib 加载超时"
                return 1
            fi
        fi
    elif [ "$no_preview" -gt 0 ]; then
        fail "未找到 #Preview block — PreviewScanner 未识别"
        return 1
    elif [ "$build_failed" -gt 0 ]; then
        fail "编译失败 — swiftc 报错"
        # 输出编译错误日志帮助诊断
        info "--- swiftc 错误日志 ---"
        local log_file
        log_file=$(get_latest_log)
        grep -i "swiftc\|error:" "$LOG_DIR/$log_file" 2>/dev/null | tail -20
        info "--- END ---"
        return 1
    else
        info "尚未检测到编译结果，再等待 5s..."
        sleep 5
        loaded_count=$(grep_log_count "entry ·")
        if [ "$loaded_count" -gt 0 ]; then
            ok "预览 dylib 已加载（延迟确认）"
        else
            fail "超时：未检测到编译结果"
            return 1
        fi
    fi
}

# 测试 5: 验证帧流产出
test_frame_production() {
    step "测试 5: 验证帧流产出"

    info "等待帧流..."
    sleep 3

    assert_log_contains "currentFrame" "收到至少一帧"
}

# 测试 6: Stop Stream
test_stop_stream() {
    step "测试 6: Stop Stream"

    local response
    response=$(send_action "inline_preview.stop_stream")
    assert_api_ok "$response" "inline_preview.stop_stream → API 响应成功" || return 1

    sleep "$STOP_STREAM_WAIT"

    assert_log_contains "stopSession" "ViewModel 收到 stopSession 调用"
    wait_for_log "Session 已停止" "Session 已完全停止" 5
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

    # 验证
    local loaded_count
    loaded_count=$(grep_log_count "entry ·")
    if [ "$loaded_count" -gt 0 ]; then
        ok "端到端：预览已加载并渲染"
    else
        info "端到端：检查编译状态..."
        local build_failed
        build_failed=$(grep_log_count "swiftc failed\|未找到")
        if [ "$build_failed" -gt 0 ]; then
            fail "端到端：编译或扫描失败"
            return 1
        else
            # 再等一会
            sleep 5
            loaded_count=$(grep_log_count "entry ·")
            if [ "$loaded_count" -gt 0 ]; then
                ok "端到端：预览已加载并渲染（延迟确认）"
            else
                fail "端到端：超时未检测到预览加载"
                return 1
            fi
        fi
    fi

    # Stop
    info "停止 Stream..."
    response=$(send_action "inline_preview.stop_stream")
    sleep "$STOP_STREAM_WAIT"
    ok "端到端：Stream 已停止"
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
