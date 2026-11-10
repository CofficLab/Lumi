# TestPlan — PluginAgentTurnNotification

## 包概述

PluginAgentTurnNotification 的实现包，包含 2 个主要类型；当前测试覆盖 7 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 7

核心组件（源码目录）:
- `Hooks/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentTurnNotificationPlugin`
- `TurnFinishedNotificationHook`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（7 条）：由 `lifecycle`、`presentationTitles`、`finishedTriggersNotifier` 等用例锁定；改动该模块时优先跑对应测试文件。通知文案必须经 `pluginLocalization` 解析，不能写死中文。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | 插件 onBoot/onShutdown 不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lifecycle` |
| 2 | 综合 | presentation 按原因经本地化解析生成标题与正文（**回归 #898**） | 注入 marker 解析器 | 以 completed / failed / cancelled / unknown 调用 `presentation` | 标题与正文分别为 `key:Task Completed` 等词条，证明不再写死中文 | P2 | ✅ 已覆盖 | `presentationTitles` |
| 3 | 综合 | V2 turn-finished hook 触发 notifier | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `finishedTriggersNotifier` |
| 4 | 综合 | 通知请求携带来源会话 ID（**回归 #1075**） | 任意会话 ID | 构造通知请求并读取 `content.userInfo` | `conversationId` 等于会话 ID 的 uuidString，标题/正文/声音保留 | P1 | ✅ 已覆盖 | `notificationRequestCarriesConversationID` |
| 5 | 综合 | 点击通知激活应用并选中来源会话（**回归 #1075**） | 注册 `DefaultConversationManager`，注入 delegate 安装/卸载与激活回调 | `onBoot` 后用安装的 handler 处理带 `conversationId` 的 userInfo，再 `onShutdown` | handler 返回 true；激活回调触发；管理器选中该会话；关闭时卸载 delegate | P1 | ✅ 已覆盖 | `tapSelectsOriginatingConversation` |
| 6 | 综合 | 缺少或非法会话 ID 的通知点击不改变选中会话 | — | 用空 userInfo 与非 UUID 字符串调用 handler | 返回 false，不激活应用、不选择会话 | P2 | ✅ 已覆盖 | `tapIgnoresInvalidConversationID` |
| 7 | 本地化 | 通知标题与正文在 en / zh-Hans / zh-Hant / zh-HK / zh-TW 下均有译文 | 编译后的资源包 | 读取各语言 `Localizable.strings` | 7 个词条都有对应译文，不回退成其它语言（**回归** #898） | P1 | ✅ 已覆盖 | `presentationLabelsHaveTranslationsInCompiledBundle` |

> 说明：全部 **7 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 5 / 5
- P2: 已覆盖 2 / 2
- **合计: 7 / 7**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（5 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 7 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAgentTurnNotification
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
