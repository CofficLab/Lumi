# TestPlan — PluginAppIconDesigner

## 包概述

PluginAppIconDesigner 的实现包，包含 14 个主要类型；当前测试覆盖 25 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 25

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
| 9 | Agent 工具 | 没有项目存储时 create_icon_document 在改状态前失败 | 未打开项目 | 调用工具 | 抛 `invalidStorageScope`，内存中无新文档 | P1 | ✅ 已覆盖 | `createIconDocumentFailsWithoutProjectStorage` |
| 10 | Agent 工具 | 没有项目存储时 apply_icon_preset 在改状态前失败 | 未打开项目 | 调用工具 | 抛 `invalidStorageScope`，内存中无新文档 | P1 | ✅ 已覆盖 | `applyIconPresetFailsWithoutProjectStorage` |
| 11 | 跨对话隔离 | 对话 A 的工具调用写入对话 A 的项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationScopedToolWritesIntoItsOwnProject` |
| 12 | 跨对话隔离 | 对话 A 的工具调用读取对话 A 的项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationScopedToolReadsFromItsOwnProject` |
| 13 | 跨对话隔离 | 跨项目写入不污染 UI 当前项目的 store | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crossProjectWriteDoesNotPolluteSharedStore` |
| 14 | 跨对话隔离 | 对话项目与当前项目相同时复用 shared store | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sameProjectReusesSharedStore` |
| 15 | 跨对话隔离 | 对话未绑定项目时回退到当前项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unscopedConversationFallsBackToCurrentProject` |
| 16 | 跨对话隔离 | 15 个工具都按对话项目路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registeredToolsAreConversationScoped` |
| 17 | 存储 | 加入项目不预建存储目录，真正写入时才创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotCreateStorageDirectoryUntilWrite` |
| 18 | Agent 工具 | `replaceSelected=true` 时用不同 ID 的 JSON 替换当前选中文档，保留其 ID 并清理旧文件 | 已选中文档 A，B 的 JSON 位于存储目录外 | 调用 `load_icon_document(inputPath=B, replaceSelected=true)` | 列表中仅一条文档，ID 为 A，内容为 B，磁盘重载也只有一条 | P1 | ✅ 已覆盖 | `loadIconDocumentReplacesSelectedDocumentWithDifferentId` |
| 19 | Agent 工具 | `replaceSelected=false` 时导入新副本而不是替换 | 已选中文档 A | 调用 `load_icon_document(inputPath=B)` | 列表两条文档，新副本拥有独立 ID 并被选中 | P1 | ✅ 已覆盖 | `loadIconDocumentImportsCopyWhenReplaceSelectedIsFalse` |
| 20 | 跨对话隔离 | 缓存的项目 store 使用前从磁盘重载，旧快照不覆盖新修订 | 项目 A 由对话缓存，UI 切到项目 A 用 shared 编辑后再切回 | 再次通过对话使用缓存 store 编辑同一文档 | 内存与磁盘都保留 shared 写入的新修订 | P1 | ✅ 已覆盖 | `cachedScopedStoreReloadsBeforeUse` |
| 21 | 导出 | 径向背景半径随导出尺寸缩放，各尺寸外观一致 | 1024 文档，径向渐变 endRadius=512 | 分别渲染 1024px 与 64px PNG | 小尺寸角落同样到达渐变末端 | P1 | ✅ 已覆盖 | `radialBackgroundScalesWithRenderSize` |
| 22 | 导出 | SVG 导出保留渐变、阴影与模糊，不丢失视觉效果 | 线性渐变背景 + 径向渐变光晕（模糊） + 带阴影矩形 | 调用 `IconSVGRenderer.render` | 输出 `linearGradient`/`radialGradient` defs、`url(#…)` 填充、多段 `stop` 及 `feGaussianBlur`/`feFlood` 滤镜 | P0 | ✅ 已覆盖 | `svgExportPreservesGradientsShadowAndBlur` |
| 23 | 导出 | SVG 导出不得把 SF Symbol 输出为字面名称 | 含 `sparkles` 符号图层与阴影 | 调用 `IconSVGRenderer.render` | 输出内嵌 base64 PNG 的 `<image>`，不出现 `<text>` 或符号名字面文本 | P0 | ✅ 已覆盖 | `svgExportRasterizesSymbolsInsteadOfLiteralNames` |
| 24 | Agent 工具 | 缺少必填参数时抛出 `ToolExecutionError`，不返回本地化错误字符串 | 无 | 调用 `apply_icon_preset` / `export_app_icon` 不传必填参数 | 两次均抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `missingParameterThrows` |
| 25 | Agent 工具 | 未知预设抛出 `ToolExecutionError` | 无 | 调用 `apply_icon_preset(presetId: not-a-preset)` | 抛出 `ToolExecutionError`，不返回错误文案 | P1 | ✅ 已覆盖 | `unknownPresetThrows` |

> 说明：全部 **25 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 17 / 17
- P2: 已覆盖 6 / 6
- **合计: 25 / 25**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（17 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 23 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
