# Lumi 自动化测试规范（大模型自测）

> 通过本地 HTTP API 驱动应用行为，用于脚本或大模型验证功能，无需 Accessibility 注入。

---

## 方案说明

```
curl / shell 脚本
  → POST http://localhost:18765/api/action  （JSON: action + payload）
  → AutomationServer 解析并分发通知
  → AutomationController 路由到处理器（直接改 VM 或写入共享状态）
```

- 仅监听 `localhost:18765`，无认证；`LUMI_AUTOMATION_SERVER=false` 可关闭服务。
- 动作定义与路由见 `AutomationController.swift`；新增动作时在该文件扩展，并补充对应测试脚本。

---

## 测试流程

### 1. 启动应用

构建并运行 Lumi（Debug 即可）。应用启动后会自动拉起 Automation Server。

### 2. 发送动作

```bash
BASE_URL="http://localhost:18765/api/action"

curl -s -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -d '{"action": "<action_name>", "payload": { } }'
```

- 成功：`{"status":"ok","message":"Action dispatched"}`
- 失败：`{"status":"error","message":"..."}`

动作名与 `payload` 字段以 `AutomationController` 中已有 `case` 为准。步骤之间留 `sleep`（约 1–5 秒），等待 UI 与异步任务完成。

### 3. 运行或补充项目脚本

`scripts/test-automation-*.sh` 覆盖的场景：优先跑脚本做回归，失败再用 `curl` 复现。

若当前场景**没有**对应脚本：在 `scripts/` 新增 `test-automation-<场景>.sh`（复用现有脚本的 `BASE_URL`、curl 与日志检查写法），再执行。

### 4. 用磁盘日志确认

目录：`~/Library/Application Support/com.coffic.Lumi/logs_debug_v2/`

只读**最新**日志文件的**末尾几行**（近期输出足够判断，不必扫全文件）：

```bash
LOG_DIR=~/Library/Application\ Support/com.coffic.Lumi/logs_debug_v2
tail -n 30 "$LOG_DIR/$(ls -t "$LOG_DIR" | head -1)"
```

**通过标准**：HTTP 返回 `ok`，且末尾日志中有 `Routing action`、🤖 或该场景预期的业务输出；仅看 HTTP 响应不够。

自动化相关日志需对动态字符串使用 `privacy: .public`，否则日志中为 `<private>`（见 [磁盘日志 Debug](./debug-with-disk-logs.md)）。

---

## 限制

- 仅支持 `POST /api/action`，面向本地自动化，不适合高并发或外网暴露。
