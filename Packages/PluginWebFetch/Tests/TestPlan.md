# TestPlan — PluginWebFetch

## 包概述

PluginWebFetch 的实现包，包含 6 个主要类型；当前测试覆盖 22 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 22

核心组件（源码目录）:
- `Internal/`
- `Services/`
- `Tools/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `WebFetchPlugin`
- `HTMLToMarkdownConverter`
- `WebFetchCache`
- `WebFetchFetching`
- `WebFetchRuntime`
- `WebFetchTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **HTMLToMarkdownConverter**（4 条）：由 `removesUnwantedContentAndDecodesEntities`、`resolvesDocumentURLs`、`convertsStructuredContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebFetchCache**（5 条）：由 `updatingExistingValueDoesNotEvict`、`addingAtCapacityEvictsOldest`、`expiresStaleValues` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebFetchPlugin**（5 条）：由 `pluginMetadata`、`pluginRegistersTool`、`toolSchemaRequiresURL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebFetchService**（8 条）：由 `validatesURLsBeforeFetching`、`fetchesResponseOnceAndServesItFromCache`、`retriesFailedHTTPResponses` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | HTMLToMarkdownConverter | removes executable content and decodes named and numeric entities | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removesUnwantedContentAndDecodesEntities` |
| 2 | HTMLToMarkdownConverter | resolves relative and protocol-relative links and images | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvesDocumentURLs` |
| 3 | HTMLToMarkdownConverter | converts lists, code, blockquotes, and escaped table cells | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsStructuredContent` |
| 4 | HTMLToMarkdownConverter | normalizes an unclosed list and truncates oversized content | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `handlesMalformedAndOversizedHTML` |
| 5 | WebFetchCache | keeps other entries when replacing a value at capacity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updatingExistingValueDoesNotEvict` |
| 6 | WebFetchCache | evicts only the oldest entry when adding a new key at capacity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addingAtCapacityEvictsOldest` |
| 7 | WebFetchCache | expires entries after the configured lifetime | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `expiresStaleValues` |
| 8 | WebFetchCache | does not store entries when capacity is zero | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroCapacityDisablesStorage` |
| 9 | WebFetchCache | clear removes all cached entries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearRemovesEntries` |
| 10 | WebFetchPlugin | plugin metadata is stable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadata` |
| 11 | WebFetchPlugin | plugin registers one web fetch tool | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersTool` |
| 12 | WebFetchPlugin | tool schema requires url | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemaRequiresURL` |
| 13 | WebFetchPlugin | tool risk level is medium | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolRiskLevel` |
| 14 | WebFetchPlugin | tool rejects missing url | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolRejectsMissingURL` |
| 15 | WebFetchService | rejects empty, malformed, and non-HTTP URLs without a request | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `validatesURLsBeforeFetching` |
| 16 | WebFetchService | fetches and caches a successful response | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fetchesResponseOnceAndServesItFromCache` |
| 17 | WebFetchService | does not cache HTTP errors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `retriesFailedHTTPResponses` |
| 18 | WebFetchService | resolves redirects and rejects redirect targets with unsafe schemes | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `handlesRedirectTargets` |
| 19 | WebFetchService | extracts matching English and Chinese paragraphs and explains a miss | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractsPromptMatches` |
| 20 | WebFetchService | formats valid JSON and reports invalid JSON without losing its body | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `formatsJSONResponses` |
| 21 | WebFetchService | routes plain text, sniffed HTML, and undecodable text | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `processesTextContentTypes` |
| 22 | WebFetchService | saves binary and image responses under the supplied temporary directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `savesDownloadedFiles` |

> 说明：全部 **22 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 16 / 16
- P2: 已覆盖 1 / 1
- **合计: 22 / 22**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（16 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 22 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginWebFetch
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
