# TestPlan — PluginMessageSender

## 包概述

PluginMessageSender 是编辑器里「发送 / 停止」这条链路的实现包。它不持有任何 UI，
只负责把用户的一次发送动作，翻译成「用户消息落库 + AgentLoop 回合跟踪 + 停止」，
并把结果通过 Provider 契约广播出去。UI 层（输入框、发送按钮、停止按钮）通过订阅
`MessageSenderEvent` 与 `isSending` 观察者决定按钮形态，因此本包是发送/停止行为的
唯一事实来源。

核心组件:
- `MessageSenderPlugin` - 装配插件（`onBoot` 解析依赖并注册 provider，`onShutdown` 拆除监听）
- `MessageSender` - `MessageSendingProviding` 的默认实现（提交、入队、回合跟踪、停止）
- `AgentLoopObserver` - 把 AgentLoop 生命周期事件转发给 `MessageSender`
- `MessageSenderObserverHandleImpl` - 事件订阅令牌（cancel 后不再回调）

## 公开 API

### MessageSenderPlugin
- `id` / `order`(= 9) / `metadata`（`policy: .required`，随宿主必装）
- `onBoot(kernel:)` - 解析 `ConversationManaging` / `MessageManaging` / `AgentLoopProviding`，
  任一缺失则记日志并 return（**不注册、也不抛错**）
- `onShutdown(kernel:)` - 取消 AgentLoop 监听

### MessageSender（`MessageSendingProviding`）
- 状态：`isSending`、`pendingImageAttachments`、`pendingFileAttachments`、`pendingQueues`
- 订阅：`addMessageSenderObserver(_:)`、`addSendingStateObserver(_:)`
- 提交：`commitUserMessage(_:conversationID:)`、
  `commitUserMessage(_:imageAttachments:fileAttachments:conversationID:)`、
  `commitUserMessageInBackground(...)`
- 发送：`sendMessage(_:conversationID:)`、`startTurn(for:)`
- 停止：`cancelCurrentRequest()`
- 恢复：`resumeTurn(in:request:)`
- 队列：`pendingMessages(for:)`、`cancelPendingMessage(id:in:)`
- 内部入口：`handleAgentLoopEvent(_:)`（由 `AgentLoopObserver` 调用）

### 关键行为契约（实现约定，非协议要求）
- **空内容短路**：`trimmed` 为空且无附件时 `commitUserMessage` 返回 nil，不写库
- **同会话串行**：发送中再次发送 → 进 `pendingQueues`，当前回合结束后由
  `drainPendingQueue` 依次发出；**用户消息立即入库**（不等待回合）
- **提交与回合分离**：`commit` 阶段同步完成，`startTurn` 才建立回合跟踪任务
- **迟到事件防护**：`suspended` 事件需同时校验 state / turnID / suspensionID 才生效
- **停止语义**：`cancelCurrentRequest()` 取消跟踪任务 + `agentLoop.cancelTurn` +
  广播 `.cancelled`，仅当无任何活动任务时才复位 `isSending = false`

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 装配 | `onBoot` 解析三项 Provider 并注册自带 `MessageSender` | 注册 Conversation / Message / AgentLoop 替身 | 走 `kernel.start(plugins:)` 真实装配路径 | provider 可解析、类型为 `MessageSender`、归属本插件（可被卸载撤回） | P0 | ✅ 已覆盖 | `pluginRegistersMessageSendingProvider` |
| 2 | 降级 | 缺依赖时 `onBoot` 不抛错且不注册（no-op） | 空内核 | 调 `plugin.onBoot(kernel:)` | 不抛错，`MessageSendingProviding` 解析为 nil | P0 | ✅ 已覆盖 | `pluginNoOpsWithoutDependencies` |
| 3 | 链路 | 注册后 `sendMessage` 走完整链路：用户消息 → 回合 → 回复 | 完整依赖 + 消息插入即触发回合的 AgentLoop 替身 | `sendMessage("hello", conversationID: nil)` | 消息序列为 `["hello", "response"]`，结束后 `isSending == false` | P0 | ✅ 已覆盖 | `registeredSenderSendsMessage` |
| 4 | 回归 | 回合已恢复时忽略迟到的旧 `suspended` 事件 | AgentLoop 替身处于 `.running` 且带 activeTurnID/suspension | 投递同 suspensionID 的 `.suspended` | 不产生 `turnCompleted`（迟到事件不结束发送任务、不启动队列下一条） | P0 | ✅ 已覆盖 | `senderIgnoresStaleSuspensionEvent` |
| 5 | 提交 | 空内容 / 纯空白内容短路，不写库、不建回合 | 直接构造 `MessageSender` | `commitUserMessage("   ", conversationID: id)` | 返回 nil，消息列表不变，`isSending == false` | P0 | ❌ 缺失 | - |
| 6 | 提交 | 有附件时即使正文为空也允许提交 | 构造带图片附件的 sender | `commitUserMessage("", conversationID: id)` | 返回非 nil commit，metadata 中含附件编码 | P1 | ❌ 缺失 | - |
| 7 | 队列 | 同会话发送中再次发送 → 入队，回合结束后自动发出 | 已有活动回合的 sender | 连续 commit 两条 → 推进 AgentLoop 结束 | 第二条先入库为 pending，队列深度可查；回合结束后两条按序发出，`pendingMessages(for:)` 归空 | P0 | ❌ 缺失 | - |
| 8 | 队列 | `cancelPendingMessage` 移除指定条目并广播变化 | 队列中有 2 条 | 移除其中 1 条 | 队列只剩 1 条，事件已广播 | P1 | ❌ 缺失 | - |
| 9 | 附件 | 附件挂起池的增 / 删 / 清空，并在发送后清空已送出的附件 | 构造 sender | 添加图片+文件 → 发送 → 检查池 | 发送后池被清空；`attachmentsChanged` 事件按实际变化次数触发 | P1 | ❌ 缺失 | - |
| 10 | 停止 | `cancelCurrentRequest` 取消活动回合并广播 `.cancelled` | 存在活动回合且该会话为选中会话 | 调 `cancelCurrentRequest` | 任务被取消、`agentLoop.cancelTurn` 被调用、`turnCompleted(.cancelled)` 广播、`isSending == false` | P0 | ❌ 缺失 | - |
| 11 | 停止 | 无活动回合时点击停止是安全 no-op | 无 selectedConversation 或无活动任务 | 调 `cancelCurrentRequest` 两次 | 不崩溃，不误改 `isSending` | P1 | ❌ 缺失 | - |
| 12 | 观察 | `isSending` 观察者仅在状态真实变化时触发，cancel 后停止 | 独立 sender | 订阅 → 反复赋值 → cancel | 回调次数与真实变化次数一致；cancel 后不再回调 | P1 | ❌ 缺失 | - |
| 13 | 观察 | `addMessageSenderObserver` 的 token cancel 后不再收到事件 | 独立 sender | 订阅 → cancel → 触发事件 | cancel 后无回调；重复 cancel 安全 | P2 | ❌ 缺失 | - |
| 14 | 恢复 | `resumeTurn` 成功/失败分别广播 `turnCompleted` / `turnFailed` 并复位 `isSending` | AgentLoop 替身可配置成功或抛错 | 调 `resumeTurn` 两种分支 | 事件与 outcome 一致；抛出原错误；`isSending` 最终为 false | P1 | ❌ 缺失 | - |
| 15 | 会话 | 未指定会话时落到选中会话；无选中则新建并自动选中 | 空会话管理器 | `commitUserMessage("x", conversationID: nil)` | 消息写入新建会话，且该会话成为 selected | P1 | ❌ 缺失 | - |
| 16 | 并发 | 两个会话并发发送，任一结束不得提前复位全局 `isSending` | 两个会话各有一个活动回合 | 先结束其中一个 | `isSending` 仍为 true，直到两者都结束 | P1 | ❌ 缺失 | - |
| 17 | 插件 | `onShutdown` 拆除 AgentLoop 监听，不再有事件转发 | 已 boot 的插件 | shutdown 后投递 AgentLoop 事件 | `MessageSender` 不再收到回调 | P2 | ❌ 缺失 | - |

> 说明：ID 1–4 已由 `MessageSenderPluginTests.swift` 的 4 个测试方法在 macOS 上实跑通过。
> ID 5–17 依赖更完整的替身能力（可控的 AgentLoop 事件、跨会话并发、附件编码断言），
> 当前套件未覆盖，标注为 ❌ 缺失而非虚假打勾。ID 5 / 7 / 10 / 16 直接对应发送与停止
> 按钮的用户可见行为，建议优先补齐。

## 覆盖率统计

- P0: 已覆盖 4 / 7
- P1: 已覆盖 0 / 7
- P2: 已覆盖 0 / 2
- **合计: 4 / 16**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 插件装配与降级、完整发送链路、空内容短路、同会话串行队列、停止取消语义
- **P1**: 附件池、观察者回调、resume 分支、会话解析、跨会话并发
- **P2**: 订阅令牌 cancel、插件 shutdown 的资源释放

## 跨平台说明

- 纯 Foundation / KernelCore 逻辑，macOS 14+ 与 iOS 17+ 行为一致
- 本包无 SwiftUI 视图，测试不依赖渲染或窗口
- 所有被测类型为 `@MainActor`，测试套件同样标注 `@MainActor` 并在主线程执行

## 测试执行

```bash
cd Packages/PluginMessageSender
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件（ID 4 即迟到 suspended 事件的回归）
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
