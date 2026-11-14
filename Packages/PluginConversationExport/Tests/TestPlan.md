# TestPlan — PluginConversationExport

## 包概述

PluginConversationExport 为 Lumi 当前聊天会话提供独立的 HTML 导出能力。 ## 功能 - 在 ChatToolbar 尾部贡献“导出”按钮。 - 异步读取当前会话的完整消息快照，不阻塞聊天界面。 - 生成不依赖网络资源的单文件 HTML，包含消息角色、时间、模型、推理与工具调用信息。 - 使用系统文件导出界面选择保存位置。 ## 验证 ```sh swift test --package-path Packages/PluginConversationExport ```

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 13

核心组件（源码目录）:
- `Export/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationExportPlugin`
- `ConversationExportViewModel`
- `ConversationHTMLDocument`
- `ConversationExportSnapshot`
- `ConversationHTMLExporter`
- `ConversationExportToolbarView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationExportPlugin**（4 条）：由 `registersToolbarItem`、`exportsSafeOrderedHTML`、`exportsToolDetailsAndImages`、`shareExportKeepsOnlyVisibleContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationExportWhitespace**（5 条）：由 `toolResultKeepsSurroundingWhitespace`、`messageContentKeepsSurroundingWhitespace`、`reasoningAndArgumentsKeepSurroundingWhitespace` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationExportLanguage**（4 条）：由 `englishConversationDeclaresEn`、`chineseConversationDeclaresZhCN`、`unsetLanguageFallsBackToZhCN` 等用例锁定；HTML 导出的 `<html lang>` 必须跟随对话回复语言，改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationExportPlugin | 插件向 ChatToolbar 注册并撤回导出入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersToolbarItem` |
| 2 | ConversationExportPlugin | HTML 导出按时间排序并转义不可信内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportsSafeOrderedHTML` |
| 3 | ConversationExportPlugin | HTML 导出保留工具结果和安全的内嵌图片 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `exportsToolDetailsAndImages` |
| 4 | ConversationExportPlugin | 分享模式隐藏技术细节，只保留用户与助手的可见内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shareExportKeepsOnlyVisibleContent` |
| 5 | ConversationExportWhitespace | 工具结果的首尾空白原样保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolResultKeepsSurroundingWhitespace` |
| 6 | ConversationExportWhitespace | 消息正文的首尾空白原样保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageContentKeepsSurroundingWhitespace` |
| 7 | ConversationExportWhitespace | 推理内容与工具参数的首尾空白原样保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasoningAndArgumentsKeepSurroundingWhitespace` |
| 8 | ConversationExportWhitespace | 附件文件体的首尾空白原样保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attachmentFileBodyKeepsSurroundingWhitespace` |
| 9 | ConversationExportWhitespace | 纯空白的内容仍然被当作空内容，不渲染正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `whitespaceOnlyContentIsStillTreatedAsEmpty` |
| 10 | ConversationExportLanguage | English conversation exports lang=en | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `englishConversationDeclaresEn` |
| 11 | ConversationExportLanguage | Chinese conversation exports lang=zh-CN | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chineseConversationDeclaresZhCN` |
| 12 | ConversationExportLanguage | Unset language falls back to zh-CN | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unsetLanguageFallsBackToZhCN` |
| 13 | ConversationExportLanguage | htmlLanguage maps each language to its declaration | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `htmlLanguageMapsEachLanguage` |

> 说明：全部 **13 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 10 / 10
- P2: 已覆盖 1 / 1
- **合计: 13 / 13**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 13 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationExport
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」