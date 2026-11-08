# TestPlan — PluginProjectOverview

## 包概述

PluginProjectOverview 项目概览插件。 提供 Agent 工具，返回项目类型、顶层结构、Git 信息、清单文件、README 预览和关键文件。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 15

核心组件（源码目录）:
- `Sections/`
- `Services/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ProjectOverviewPlugin`
- `GitSection`
- `KeyFilesSection`
- `ManifestSection`
- `ProjectTypeSection`
- `ReadmePreviewSection`
- `StructureSection`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ProjectOverviewPlugin**（12 条）：由 `pluginMetadata`、`pluginRegistersTool`、`promptSuggestionRequiresProject` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProjectOverviewConversationScope**（3 条）：由 `usesConversationProject`、`explicitPathWins`、`missingPathThrows` 锁定；工具必须按调用所属会话的项目读取，显式 path 优先；路径不存在必须抛出。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ProjectOverviewPlugin | plugin metadata is stable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadata` |
| 2 | ProjectOverviewPlugin | plugin registers one tool | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersTool` |
| 3 | ProjectOverviewPlugin | prompt suggestion requires a project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `promptSuggestionRequiresProject` |
| 4 | ProjectOverviewPlugin | tool name and description | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolMetadata` |
| 5 | ProjectOverviewPlugin | tool input schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolInputSchema` |
| 6 | ProjectOverviewPlugin | tool risk level is low | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolRiskLevel` |
| 7 | ProjectOverviewPlugin | ProjectTypeSection detects Swift project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectTypeDetectsSwift` |
| 8 | ProjectOverviewPlugin | KeyFilesSection detects README | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keyFilesDetectsReadme` |
| 9 | ProjectOverviewPlugin | GitSection handles non-git directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gitSectionHandlesNonGit` |
| 10 | ProjectOverviewPlugin | localization catalog is packaged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizationCatalogIsPackaged` |
| 11 | ProjectOverviewConversationScope | 未传 path 时读取会话绑定项目，而不是 UI 当前项目 | 会话绑定项目 A，UI 当前为 B | 调用 `executeResult(context:arguments:)` | 概览路径为 A | P1 | ✅ 已覆盖 | `usesConversationProject` |
| 12 | ProjectOverviewConversationScope | 显式 path 优先于会话绑定项目 | 会话绑定 A，显式传 B | 调用 `executeResult(context:arguments:)` | 概览路径为 B | P1 | ✅ 已覆盖 | `explicitPathWins` |
| 13 | ProjectOverviewConversationScope | 路径不存在时抛出错误而非返回错误字符串 | 传入不存在的临时路径 | 调用 `executeResult(context:arguments:)` | 抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `missingPathThrows` |
| 14 | ProjectOverviewPlugin | 仓库子目录也能被发现所属工作树（**回归 #978**） | 临时目录 `git init`，传入其 `Sources/` 子目录（子目录内无 `.git`），并放一个未跟踪文件 | 调用 `GitSection.render(at:)` | 返回 `Repository: Yes` 与 `Status: Uncommitted changes`，不再返回 `Not a Git repository.` | P1 | ✅ 已覆盖 | `gitSectionDetectsEnclosingWorktree` |
| 15 | ProjectOverviewPlugin | README 超过 2,000 字节上限时附加省略标记（**回归 #979**） | README 为 501 个 `😀`（4 字节/字符），2,000 字节读取块恰好落在完整字符边界 | 调用 `ReadmePreviewSection.render(at:)` | 预览为 500 个字符且以 `\n...` 结尾，不再把被截断内容表现为完整预览 | P1 | ✅ 已覆盖 | `readmePreviewMarksContentBeyondByteCap` |

> 说明：全部 **15 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 14 / 14
- P2: 已覆盖 1 / 1
- **合计: 15 / 15**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 15 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginProjectOverview
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
