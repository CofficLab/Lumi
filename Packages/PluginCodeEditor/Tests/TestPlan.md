# TestPlan — PluginCodeEditor

## 包概述

PluginCodeEditor 的实现包，包含 10 个主要类型；当前测试覆盖 11 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 11

核心组件（源码目录）:
- `Observers/`
- `Theme/`
- `Workbench/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `CodeEditorAboutView`
- `CodeEditorLocalization`
- `CodeEditorManualView`
- `CodeEditorPlugin`
- `CodeEditorViewModel`
- `SendSelectionToConversationContributor`
- `CodeEditorProjectObserver`
- `CodeEditorThemeObserver`
- `CodeEditorThemeAdapter`
- `EditorWorkbenchView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CodeEditorSuperPlugin**（5 条）：由 `metadata`、`localizationCatalogProvidesSupportedLocales`、`lifecycle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CodeEditorViewModel**（2 条）：由 `loadsCurrentFile`、`clearsCurrentFile` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SendSelectionToConversationContributor**（4 条）：由 `selectedTextUsesUTF16Range`、`messagePayloadIncludesContext`、`appendPreservesExistingInput` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CodeEditorSuperPlugin | is user configurable and disabled by default | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `metadata` |
| 2 | CodeEditorSuperPlugin | 本地化资源覆盖元数据与手册文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `localizationCatalogProvidesSupportedLocales` |
| 3 | CodeEditorSuperPlugin | enabling and disabling installs and removes workspace contributions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lifecycle` |
| 4 | CodeEditorSuperPlugin | 同步 ThemeProviding 主题到编辑器 Host 契约 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `themeChangesSyncToEditor` |
| 5 | CodeEditorSuperPlugin | 主题语义色板可转换为编辑器语法色板 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `themePaletteMapsToEditorPalette` |
| 6 | CodeEditorViewModel | loads the current project file into the editor | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsCurrentFile` |
| 7 | CodeEditorViewModel | clearing the current project file clears the editor | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearsCurrentFile` |
| 8 | SendSelectionToConversationContributor | reads a UTF-16 selection without breaking Unicode text | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedTextUsesUTF16Range` |
| 9 | SendSelectionToConversationContributor | builds a code payload with relative file and line context | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messagePayloadIncludesContext` |
| 10 | SendSelectionToConversationContributor | appends to the conversation input and focuses it | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendPreservesExistingInput` |
| 11 | SendSelectionToConversationContributor | contributes only when a conversation input provider is available | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextMenuContributionRequiresConversationInput` |

> 说明：全部 **11 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 9 / 9
- P2: 已覆盖 2 / 2
- **合计: 11 / 11**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（9 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 11 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginCodeEditor
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
