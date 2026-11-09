# TestPlan — PluginDocxRead

## 包概述

PluginDocxRead 的实现包，包含 2 个主要类型；当前测试覆盖 10 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 10

核心组件（源码目录）:
- `Services/`
- `Tools/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DocxReadPlugin`
- `DocxReadTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DocxReadPlugin**（2 条）：由 `pluginRegistersAndRemovesItsAgentTools`、`pluginLifecycleToleratesMissingToolManager` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DocxReadTool**（8 条）：由 `toolMetadataDescribesRequiredPathAndLowRiskRead`、`executeRejectsMissingPathAndThrowsForMissingFile`、`executeReturnsExtractedAndEmptyDocumentContent` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DocxReadPlugin | pluginRegistersAndRemovesItsAgentTools | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersAndRemovesItsAgentTools` |
| 2 | DocxReadPlugin | pluginLifecycleToleratesMissingToolManager | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginLifecycleToleratesMissingToolManager` |
| 3 | DocxReadTool | toolMetadataDescribesRequiredPathAndLowRiskRead | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolMetadataDescribesRequiredPathAndLowRiskRead` |
| 4 | DocxReadTool | executeRejectsMissingPathAndThrowsForMissingFile | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `executeRejectsMissingPathAndThrowsForMissingFile` |
| 5 | DocxReadTool | executeReturnsExtractedAndEmptyDocumentContent | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `executeReturnsExtractedAndEmptyDocumentContent` |
| 6 | DocxReadTool | executePropagatesExtractionErrors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executePropagatesExtractionErrors` |
| 7 | DocxReadTool | systemTextutilExtractsAValidDocxFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `systemTextutilExtractsAValidDocxFile` |
| 8 | DocxReadTool | 结构有效但无正文的 DOCX 返回空文档提示 | 用 textutil 由空文本生成真实 DOCX | 调用 `read_docx` 读取 | 返回 `(empty DOCX)`，不误报失败 | P2 | ✅ 已覆盖 | `systemTextutilReturnsEmptyContentForValidDocxWithoutText` |
| 9 | DocxReadTool | 零字节与非 ZIP 文件被判定为无效 DOCX（**回归 #1076**） | 准备 0 字节 `.docx` 与纯文本改名的 `.docx` | 分别调用 `read_docx` | 两者都抛 `ToolExecutionError`，文案包含 `not a valid DOCX` | P0 | ✅ 已覆盖 | `executeRejectsZeroByteAndNonZipFiles` |
| 10 | DocxReadTool | 截断的 DOCX 被拒绝 | 用 textutil 生成有效 DOCX 后截断为前 64 字节 | 调用 `read_docx` | 抛 `ToolExecutionError`，不返回空文档提示 | P1 | ✅ 已覆盖 | `systemTextutilRejectsTruncatedDocxFile` |

> 说明：全部 **10 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 6 / 6
- P2: 已覆盖 2 / 2
- **合计: 10 / 10**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（6 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 10 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDocxRead
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
