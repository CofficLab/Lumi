# TestPlan — PluginWebSearch

## 包概述

PluginWebSearch 的实现包，包含 3 个主要类型；当前测试覆盖 14 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 14

核心组件（源码目录）:
- `Services/`
- `Tools/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `WebSearchPlugin`
- `WebSearchRuntime`
- `WebSearchTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **WebSearchPlugin**（10 条）：由 `pluginMetadata`、`pluginRegistersTool`、`toolSchemaRequiresQuery` 等用例锁定；改动该模块时优先跑对应测试文件。`web_search` 声明 `parallelReadOnly`（#1312）：无共享可变状态，网络请求与 HTML 解析均为每次调用独立；并发查询不得互相污染结果。
- **WebSearch bad status**（4 条）：由 `rateLimitThrowsBadStatus`、`serverErrorThrowsBadStatus`、`successStillParsesResults`、`successWithNoResultsStaysEmpty` 锁定。覆盖「非 2xx 必须按真实状态码抛出 `WebSearchError.badStatus`，不得把 429/500 错误页伪装成合法空结果（**回归 #332**）」以及「2xx 的正常解析与合法空结果不受影响」；改动 `fetchDuckDuckGoResults` 的状态码判定或 HTML 解析时必须优先跑该文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | WebSearchPlugin | plugin metadata is stable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadata` |
| 2 | WebSearchPlugin | plugin registers one web search tool | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersTool` |
| 3 | WebSearchPlugin | tool schema requires query | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemaRequiresQuery` |
| 4 | WebSearchPlugin | tool risk level is low | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolRiskLevel` |
| 5 | WebSearchPlugin | tool trims copied query whitespace | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolTrimsCopiedQueryWhitespace` |
| 6 | WebSearchPlugin | tool rejects blank copied query | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolRejectsBlankCopiedQuery` |
| 7 | WebSearchPlugin | tool reports empty search result | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolReportsEmptySearchResult` |
| 8 | WebSearchPlugin | tool parses DuckDuckGo html results | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolParsesDuckDuckGoHTMLResults` |
| 9 | WebSearchPlugin | 工具声明并行只读能力（#1312） | — | 读取 `executionCapability` | 为 `.parallelReadOnly` | P1 | ✅ 已覆盖 | `toolDeclaresParallelReadOnly` |
| 10 | WebSearchPlugin | 并发搜索结果互不污染（#1312） | 可注入 search client 按查询返回结果 | 并发执行 4 个查询 | 每份输出只含自己的标题标记，不含其他查询的标记 | P1 | ✅ 已覆盖 | `concurrentSearchesKeepResultsIndependent` |
| 11 | WebSearch bad status | 429 错误页必须抛出 badStatus，不得伪装成无结果（**回归 #332**） | 网络替身返回 429 + 不含 result__a 的错误页 | 调用 `fetchDuckDuckGoResults` | 抛出 `WebSearchError.badStatus(429)`，而非空结果 | P0 | ✅ 已覆盖 | `rateLimitThrowsBadStatus` |
| 12 | WebSearch bad status | 500 错误页必须按真实状态码抛出 badStatus（**回归 #332**） | 网络替身返回 500 + 错误页 | 调用 `fetchDuckDuckGoResults` | 抛出 `WebSearchError.badStatus(500)` | P0 | ✅ 已覆盖 | `serverErrorThrowsBadStatus` |
| 13 | WebSearch bad status | 200 响应仍正常解析真实结果 | 网络替身返回 200 + 含 result__a 的结果页 | 调用 `fetchDuckDuckGoResults` | 解析出标题与 URL | P1 | ✅ 已覆盖 | `successStillParsesResults` |
| 14 | WebSearch bad status | 200 响应无结果时仍是合法空结果 | 网络替身返回 200 + 不含 result__a 的页面 | 调用 `fetchDuckDuckGoResults` | 返回空数组（不被误判为错误） | P2 | ✅ 已覆盖 | `successWithNoResultsStaysEmpty` |

> 说明：全部 **14 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 8 / 8
- P2: 已覆盖 3 / 3
- **合计: 14 / 14**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（8 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 14 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginWebSearch
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
