# TestPlan — PluginResumeDesigner

## 包概述

PluginResumeDesigner 的实现包，包含 14 个主要类型；当前测试覆盖 15 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 15

核心组件（源码目录）:
- `Observers/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ResumeDesignerPlugin`
- `ResumeDesignerRuleContributor`
- `ResumeDesignerSkillContributor`
- `ResumeDesignerProjectObserver`
- `ResumeDesignerLocalization`
- `ResumeDesignerRuntime`
- `CreateResumeTool`
- `ExportResumeTool`
- `ImportResumeAssetTool`
- `LintResumeTool`
- `ListResumesTool`
- `PatchResumeHTMLTool`
- `PreviewResumePageTool`
- `ReadResumeHTMLTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ResumeDesignerPlugin**（3 条）：由 `registersAndActivatesContributions`、`promptSuggestionLocalizationResolves`、`registersAndRemovesAgentTools` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeDesignerRuleContributor**（1 条）：由 `loadsResumeRuleFromResource` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeDocumentStore**（4 条）：由 `fullCRUD`、`rejectsInvalidSlugAndDuplicate`、`patchRequiresUniqueOldText` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeTools**（7 条）：由 `createResumeToolCreatesDocument`、`listResumesToolListsDocuments`、`readResumeToolReturnsMetadata` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ResumeDesignerPlugin | 启动后注册 ActivityBar 入口、Rail 标签与 Docs 文档，停止后全部撤回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndActivatesContributions` |
| 2 | ResumeDesignerPlugin | 提示词标题本地化 key 可解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `promptSuggestionLocalizationResolves` |
| 3 | ResumeDesignerPlugin | 启动后 10 个 Agent 工具注册到 ToolManagerProviding，停止后移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndRemovesAgentTools` |
| 4 | ResumeDesignerRuleContributor | 简历设计插件从 Markdown 资源贡献 Agent Rule | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsResumeRuleFromResource` |
| 5 | ResumeDocumentStore | 创建、读取、替换、补丁与删除的完整生命周期 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullCRUD` |
| 6 | ResumeDocumentStore | 非法 slug 与重复创建分别抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidSlugAndDuplicate` |
| 7 | ResumeDocumentStore | 补丁要求旧文本唯一，缺失或重复均抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `patchRequiresUniqueOldText` |
| 8 | ResumeDocumentStore | listResumes 返回全部简历并按更新时间倒序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listsResumesNewestFirst` |
| 9 | ResumeTools | resume_create 创建简历并落盘（manifest + index.html） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createResumeToolCreatesDocument` |
| 10 | ResumeTools | resume_list 列出已创建的简历 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listResumesToolListsDocuments` |
| 11 | ResumeTools | resume_read 返回 manifest 元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readResumeToolReturnsMetadata` |
| 12 | ResumeTools | resume_lint 对模板输出 PASS | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lintResumeToolPassesOnTemplate` |
| 13 | ResumeTools | resume_patch_html 原子应用补丁并更新 HTML | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `patchResumeHTMLToolAppliesPatch` |
| 14 | ResumeTools | resume_create 拒绝非法 paper 值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createResumeToolRejectsInvalidPaper` |
| 15 | ResumeTools | resume_create 缺少必填 slug 抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createResumeToolRejectsMissingSlug` |

> 说明：全部 **15 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 10 / 10
- P2: 已覆盖 1 / 1
- **合计: 15 / 15**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 15 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginResumeDesigner
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
