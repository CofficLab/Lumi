# TestPlan — PluginAppIconDesigner

## 包概述

PluginAppIconDesigner 的实现包，包含 14 个主要类型；当前测试覆盖 8 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 8

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppIconDesignerPlugin`
- `AppIconDesignerRuleContributor`
- `AppIconDesignerSkillContributor`
- `AppIconArtifact`
- `IconDocument`
- `IconPreset`
- `IconDesignerProjectObserver`
- `AppIconArtifactStore`
- `AppIconDesignerLocalization`
- `AppIconExportService`
- `IconComposerExportService`
- `IconScope`
- `IconDocumentFileService`
- `IconDocumentFileStore`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AppIconDesignerPlugin**（7 条）：由 `registersAndActivatesContributions`、`registersPromptSuggestionWhileDisabled`、`promptSuggestionLocalizationResolves` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AppIconDesignerRuleContributor**（1 条）：由 `contributesAppIconRule` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AppIconDesignerPlugin | 启动后注册 ActivityBar 与 Rail，并在激活时联动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndActivatesContributions` |
| 2 | AppIconDesignerPlugin | 禁用时仍注册提示词，并标记为需要启用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersPromptSuggestionWhileDisabled` |
| 3 | AppIconDesignerPlugin | 提示词标题本地化 key 可解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `promptSuggestionLocalizationResolves` |
| 4 | AppIconDesignerPlugin | 图标文档在项目作用域创建并落盘 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `createsAndPersistsProjectDocument` |
| 5 | AppIconDesignerPlugin | 启动后 15 个 Agent 工具注册到 ToolManagerProviding，停止后移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndRemovesAgentTools` |
| 6 | AppIconDesignerPlugin | create_icon_document 工具可执行并创建文档 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `executeCreateIconDocumentTool` |
| 7 | AppIconDesignerPlugin | preview_icon 工具返回带 PNG 图片附件的结构化结果 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `executePreviewIconToolReturnsImage` |
| 8 | AppIconDesignerRuleContributor | 图标设计插件贡献自己的 Agent Rule | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `contributesAppIconRule` |

> 说明：全部 **8 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 3 / 3
- P2: 已覆盖 5 / 5
- **合计: 8 / 8**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（3 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 8 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAppIconDesigner
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
