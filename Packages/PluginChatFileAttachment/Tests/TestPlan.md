# TestPlan — PluginChatFileAttachment

## 包概述

PluginChatFileAttachment 的实现包，包含 2 个主要类型；当前测试覆盖 6 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 6

核心组件（源码目录）:
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ChatFileAttachmentPlugin`
- `ChatFileAttachmentButton`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ChatFileAttachmentPlugin**（2 条）：由 `pluginRegistersTheFilePickerInTheLeadingActionBarAndRemovesIt`、`pluginLifecycleToleratesMissingChatProvider` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ChatFileAttachmentButton**（4 条）：由 `staleFileSelectionDoesNotLeakIntoNewConversation`、`staleBatchSelectionDoesNotLeakIntoNewConversation`、`staleFileSelectionErrorDoesNotLeakIntoNewConversation` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ChatFileAttachmentPlugin | pluginRegistersTheFilePickerInTheLeadingActionBarAndRemovesIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersTheFilePickerInTheLeadingActionBarAndRemovesIt` |
| 2 | ChatFileAttachmentPlugin | pluginLifecycleToleratesMissingChatProvider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginLifecycleToleratesMissingChatProvider` |
| 3 | ChatFileAttachmentButton | 读取期间切换会话，旧文件附件不得落入新会话挂起池（#161） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleFileSelectionDoesNotLeakIntoNewConversation` |
| 4 | ChatFileAttachmentButton | 读取期间切换会话，整批旧文件附件都不得落入新会话挂起池（#161） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleBatchSelectionDoesNotLeakIntoNewConversation` |
| 5 | ChatFileAttachmentButton | 读取期间切换会话，旧文件读取失败不得报错到新会话（#161） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleFileSelectionErrorDoesNotLeakIntoNewConversation` |
| 6 | ChatFileAttachmentButton | 未切换会话时，选择的文件正常进入挂起池 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileSelectionInSameConversationAttaches` |

> 说明：全部 **6 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（#161）：删除 `handle` 成功与错误分支的会话身份 guard 后，3 条切换会话用例转红（附件/错误落入新会话），正向用例与插件生命周期用例不受影响；恢复后 6/6 通过。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 3 / 3
- P2: 已覆盖 0 / 0
- **合计: 6 / 6**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（3 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 6 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginChatFileAttachment
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
