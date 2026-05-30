#!/usr/bin/env bash
#
# test-automation-project-persistence.sh
#
# 验证：选择项目 → 持久化到 window_states.json → 重启后 scope 恢复项目
#
# 前置：Lumi Debug 已构建；脚本会启动/重启应用
#
set -euo pipefail

APP_SUPPORT_DIR="$HOME/Library/Application Support/com.coffic.lumi"
DB_DIR="$APP_SUPPORT_DIR/db_debug_v2"
STATES_FILE="$DB_DIR/WindowPersistence/settings/window_states.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/automation-server.sh"
LOG_DIR="$(lumi_file_log_dir)"
BASE_URL="$(lumi_automation_api_url "${LUMI_AUTOMATION_PORT:-18765}")"
PROJECT_PATH="${PROJECT_PATH:-$REPO_ROOT}"
export PROJECT_PATH
APP_NAME="Lumi"
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
            -d "{\"action\": \"$action\", \"payload\": {}}"
    fi
}

wait_for_server() {
    local i
    for i in $(seq 1 40); do
        if BASE_URL="$(lumi_resolve_automation_base_url)"; then
            info "Automation Server 地址: $BASE_URL"
            return 0
        fi
        sleep 0.5
    done
    return 1
}

tail_logs() {
    local n="${1:-40}"
    LOG_DIR="$(lumi_file_log_dir)"
    if [ -d "$LOG_DIR" ]; then
        local latest
        latest=$(ls -t "$LOG_DIR" 2>/dev/null | head -1)
        if [ -n "$latest" ]; then
            tail -n "$n" "$LOG_DIR/$latest"
        fi
    fi
}

kill_lumi() {
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 1
}

launch_lumi() {
    local app_path
    app_path=$(find "$BUILD_DIR" -path "*/Build/Products/Debug/Lumi.app" -type d 2>/dev/null | grep -v "Index.noindex" | head -1)
    if [ -z "$app_path" ]; then
        fail "找不到 Debug/Lumi.app，请先 xcodebuild"
        exit 1
    fi
    info "启动 $app_path"
    open -a "$app_path"
}

assert_json_has_project() {
    if [ ! -f "$STATES_FILE" ]; then
        fail "window_states.json 不存在: $STATES_FILE"
        return 1
    fi
    python3 -c "
import json, sys
p='$STATES_FILE'
with open(p) as f: data=json.load(f)
if not data:
    print('empty array'); sys.exit(1)
path=data[0].get('projectPath') or ''
print('projectPath=', path)
if not path:
    sys.exit(2)
if path != '$PROJECT_PATH':
    print('expected=', '$PROJECT_PATH')
    sys.exit(3)
sys.exit(0)
" || return 1
    ok "磁盘 window_states.json 含本次选择的 projectPath"
}

step "构建 Debug"
cd "$REPO_ROOT"
xcodebuild -scheme Lumi -destination 'platform=macOS' build -quiet

step "结束已有 Lumi 进程"
kill_lumi

step "冷启动应用"
launch_lumi

step "等待 Automation Server"
if ! wait_for_server; then
    fail "Automation Server 未就绪"
    tail_logs 30
    exit 1
fi
ok "Automation Server 就绪"

step "等待 UI 与恢复流程"
sleep 4

step "选择项目（模拟用户）"
RESP=$(send_action "project.select" "{\"path\": \"$PROJECT_PATH\"}")
info "响应: $RESP"
echo "$RESP" | grep -q '"status":"ok"' || { fail "project.select 失败"; exit 1; }
sleep 2

step "检查持久化文件"
assert_json_has_project

step "调试快照（重启前）"
send_action "project.debug_state" >/dev/null
sleep 1

step "退出应用"
send_action "app.terminate" >/dev/null
sleep 3

step "再次启动"
launch_lumi
if ! wait_for_server; then
    fail "重启后 Automation Server 未就绪"
    exit 1
fi
sleep 5

step "重启后调试快照"
RESP=$(send_action "project.debug_state")
info "响应: $RESP"
sleep 1

step "重启后不应再要求选项目（scope 已有项目）"
PROJECT_STATE_JSON="$RESP" python3 <<'PY'
import json, os

body = os.environ["PROJECT_STATE_JSON"]
expected = os.environ["PROJECT_PATH"]
state = json.loads(body)
print("projectSelected=", state.get("projectSelected"))
print("projectPath=", state.get("projectPath"))
if state.get("status") != "ok":
    raise SystemExit("FAIL: project.debug_state did not return ok")
if not state.get("projectSelected"):
    raise SystemExit("FAIL: project is not selected after restart")
actual = state.get("projectPath") or ""
if not actual:
    raise SystemExit("FAIL: projectPath is empty after restart")
if actual != expected:
    raise SystemExit(f"FAIL: restored projectPath mismatch: {actual!r} != {expected!r}")
PY
ok "重启后 scope 恢复到本次选择的项目，不应弹出选项目界面"

step "检查日志中的恢复记录与选项目界面（辅助诊断）"
if tail_logs 80 | grep -E "prepare restoration|applied first record|first record projectPath|plugin.window-persistence" >/dev/null; then
    ok "日志包含窗口恢复记录"
else
    info "日志未找到恢复相关输出（以 project.debug_state 为准）"
    tail_logs 50
fi

if tail_logs 80 | grep -E "overlay decision.*willShow=false|willShow=false.*projectVM.selected=true" >/dev/null; then
    ok "日志显示不应弹出选项目界面 (willShow=false)"
elif tail_logs 80 | grep "overlay decision" >/dev/null; then
    fail "选项目界面决策日志显示仍会弹出"
    tail_logs 80 | grep "overlay decision" | tail -3
    exit 1
else
    info "无 overlay decision 日志（可能 verbose 关闭），跳过"
fi

step "解析磁盘与自动化状态"
python3 <<PY
import json, urllib.request, os
states_path = os.path.expanduser("$STATES_FILE")
with open(states_path) as f:
    disk = json.load(f)
disk_path = (disk[0].get("projectPath") or "") if disk else ""
req = urllib.request.Request(
    "$BASE_URL",
    data=json.dumps({"action": "project.debug_state", "payload": {}}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req) as r:
    body = r.read().decode()
print("disk projectPath:", disk_path)
if not disk_path:
    raise SystemExit("FAIL: disk has no projectPath after restart prep")
if disk_path != "$PROJECT_PATH":
    raise SystemExit("FAIL: disk projectPath mismatch")
print("PASS: disk still has expected projectPath")
PY

ok "项目持久化自测完成"
info "若仍出现选项目界面，请查看日志末尾: tail -n 50 \"$LOG_DIR/\$(ls -t \"$LOG_DIR\"|head -1)\""
