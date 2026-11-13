# TestPlan — PluginSubagent

## 包概述

PluginSubagent 的实现包：子代理委托（#1313）的隐藏子会话管道与后续的 `run_subagent` 工具。当前测试覆盖 7 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 7

核心组件（源码目录）:
- `SubagentConversationBridge.swift`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `SubagentConversationError`
- `SubagentConversationBridge`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **SubagentChildConversation**（7 条）：由 `childIsHiddenFromListAndKeepsSelection`、`childInheritsParentProjectModelAndAutomation`、`unboundParentDoesNotBindChildToCurrentProject` 等用例锁定。子会话以 `parentConversationID` 标记归属：不进入会话列表缓存、不改变选中、不发 `.created`；继承父会话的项目绑定（含「明确不绑定」，不得回退当前项目）、模型与自动化等级；消息与父会话完全隔离；删除父会话时连带取消回合、清消息、删工具记录、删库行。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | SubagentChildConversation | 子会话不进入列表、不改变选中、不发 created 事件 | 真实 ConversationStore + ConversationManager，已创建根会话 | 经桥接创建子会话 | 列表只含根会话；选中不变；无 `.created(child)`；库行 parentConversationID 指向根 | P0 | ✅ 已覆盖 | `childIsHiddenFromListAndKeepsSelection` |
| 2 | SubagentChildConversation | 子会话继承父会话的项目、模型与自动化等级 | 根会话绑定项目与模型，全局自动化为 chat，根会话覆盖为 autonomous | 经桥接创建子会话 | 子会话 projectPath/modelID 与根一致；automationLevel(for: child) 为 autonomous | P1 | ✅ 已覆盖 | `childInheritsParentProjectModelAndAutomation` |
| 3 | SubagentChildConversation | 父会话明确不绑定项目时，子会话不回退到当前项目 | 当前项目存在，根会话以 binding=.none 创建 | 经桥接创建子会话 | 子会话 projectPath 为 nil | P0 | ✅ 已覆盖 | `unboundParentDoesNotBindChildToCurrentProject` |
| 4 | SubagentChildConversation | 子会话消息不进入父会话历史，父会话消息不进入子会话历史 | 父子会话各插入消息 | 分别读取 messagesForLLM | 两侧历史只含各自消息 | P0 | ✅ 已覆盖 | `childMessagesStayOutOfParentHistory` |
| 5 | SubagentChildConversation | 删除父会话连带删除子会话库行并清空子会话消息 | 子会话已有消息 | deleteConversation(父) 后等待异步清理 | 父子库行均消失；子会话消息为空 | P0 | ✅ 已覆盖 | `deletingParentCascadesChildRowAndMessages` |
| 6 | SubagentChildConversation | 删除父会话连带取消子会话回合并删除其工具调用记录 | 注入 AgentLoop/ToolManager 替身 | deleteConversation(父) 后等待异步清理 | 替身收到父与子的 cancelTurn/deleteToolCalls | P0 | ✅ 已覆盖 | `deletingParentCancelsChildTurnAndClearsToolCalls` |
| 7 | SubagentChildConversation | 父会话不存在时抛出 parentConversationNotFound | 空会话管理器 | 用不存在的父 ID 创建子会话 | 抛出 SubagentConversationError.parentConversationNotFound | P1 | ✅ 已覆盖 | `missingParentThrows` |

> 说明：全部 **7 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 2 / 2
- P2: 已覆盖 0 / 0
- **合计: 7 / 7**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（2 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 7 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginSubagent
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」