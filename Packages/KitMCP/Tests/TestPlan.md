# TestPlan — KitMCP

## 包概述

KitMCP Lumi 的 MCP（Model Context Protocol）客户端核心 Kit 包。 - 提供与 UI/插件无关的 MCP 客户端能力：服务器配置模型、传输层（stdio / Streamable HTTP）、 会话生命周期（initialize / listTools / callTool）、工具描述与调用结果模型。 - 底层使用官方 `modelcontextprotocol/swift-sdk`（精确锁版 `0.12.1`，官方分级 Tier 3）， 通过 `MCPServerServing` 薄抽象隔离，替换实现不影响上层调用方。 - 不依赖任何其他 Lumi 包；只被 `PluginMCP`（或宿主）依赖。

平台: macOS 13+, iOS 17+
测试文件: 4 个，用例总数: 36

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MCPImageContent`
- `MCPContentCodec`
- `MCPJSONValue`
- `MCPTransport`
- `MCPClientError`
- `MCPPreparedTransport`
- `MCPToolDescriptor`
- `MCPToolSchema`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MCPContentCodec**（7 条）：由 `textAndImage`、`resourceLink`、`errorFlag` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPJSONValue**（8 条）：由 `valueRoundTrip`、`foundationValue`、`fromFoundation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPServerSession**（10 条）：由 `listAndCallTool`、`errorResult`、`notConnected` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPToolSchema**（11 条）：由 `parametersMatchDirectParsing`、`normalizedJSONMatchesDirectSerialization`、`invalidJSONYieldsNil` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MCPContentCodec | 文本与图片混合编码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textAndImage` |
| 2 | MCPContentCodec | resourceLink 以文本标记呈现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resourceLink` |
| 3 | MCPContentCodec | isError 透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorFlag` |
| 4 | MCPContentCodec | 仅 structuredContent 序列化为 JSON 文本（**#180**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `structuredContentOnly` |
| 5 | MCPContentCodec | content 与 structuredContent 同时保留（**#180**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentAndStructuredContent` |
| 6 | MCPContentCodec | 嵌套 structuredContent 仍是合法 JSON 且内容保真（**#180**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedStructuredContentIsValidJSON` |
| 7 | MCPContentCodec | structuredContent 为 nil 时文本编码不变（**#180**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `structuredContentNilPreservesText` |
| 8 | MCPJSONValue | MCP Value 往返转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueRoundTrip` |
| 9 | MCPJSONValue | foundationValue 产生 JSON 兼容对象 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foundationValue` |
| 10 | MCPJSONValue | fromFoundation 含不支持的值时整体返回 nil（不静默丢参数） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fromFoundation` |
| 11 | MCPJSONValue | jsonString 输出规范 JSON | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `jsonString` |
| 12 | MCPJSONValue | MCPValueCoding 把上层参数字典转为 MCP Value | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mcpArguments` |
| 13 | MCPJSONValue | JSON 数字 0/1 不得被误判为布尔（回归 #1154） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `jsonZeroAndOneStayNumbers` |
| 14 | MCPJSONValue | MCP 调用参数中的 JSON 0/1 以数字送达（回归 #1154） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mcpArgumentsPreserveJSONZeroAndOne` |
| 15 | MCPJSONValue | 原生 Swift 布尔与数字的桥接行为不变（回归 #1154） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nativeSwiftBoolAndNumbersUnchanged` |
| 16 | MCPServerSession | 连接后列出工具并调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listAndCallTool` |
| 17 | MCPServerSession | 服务器报错时 isError 透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorResult` |
| 18 | MCPServerSession | 未连接时调用抛 notConnected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `notConnected` |
| 19 | MCPServerSession | 重复连接是幂等的 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `connectIdempotent` |
| 20 | MCPServerSession | 仅返回 structuredContent 的成功结果序列化为 JSON 文本（**#180**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `structuredContentOnlyResult` |
| 21 | MCPServerSession | content 与 structuredContent 同时返回时两者都保留（**#180**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentAndStructuredContentResult` |
| 22 | MCPServerSession | listTools 跟随 nextCursor 逐页聚合（**#181**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listToolsFollowsPagination` |
| 23 | MCPServerSession | listTools 首页即空游标时终止（**#181**） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `listToolsStopsOnEmptyCursor` |
| 24 | MCPServerSession | listTools 跨页重名工具去重保留首次出现（**#181**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listToolsDeduplicatesAcrossPages` |
| 25 | MCPServerSession | listTools 游标重复时终止而非无限翻页（**#181**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listToolsStopsOnRepeatedCursor` |
| 26 | MCPToolSchema | 解析结果与 JSONSerialization 直接解析一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parametersMatchDirectParsing` |
| 27 | MCPToolSchema | 规范化文本与直接序列化一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedJSONMatchesDirectSerialization` |
| 28 | MCPToolSchema | 非法 JSON 时参数与规范化文本均为 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidJSONYieldsNil` |
| 29 | MCPToolSchema | 解析失败时回退到空 schema | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidJSONFallsBackToEmptyParameters` |
| 30 | MCPToolSchema | 空 schema 解析为合法对象 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyJSONObjectParses` |
| 31 | MCPToolSchema | 规范化字节数等于规范化文本长度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `byteCountMatchesNormalizedText` |
| 32 | MCPToolSchema | 描述符的 inputSchemaDictionary 返回预解析结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `descriptorReturnsPreparsedSchema` |
| 33 | MCPToolSchema | 描述符的相等性只看原始字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `descriptorEqualityIgnoresDerivedSchema` |
| 34 | MCPToolSchema | 描述符的相等性能区分不同 schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `descriptorEqualityDistinguishesSchemas` |
| 35 | MCPToolSchema | 重复访问描述符的 schema 不会改变内容 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedAccessIsStable` |
| 36 | MCPToolSchema | 重复读取 schema 的耗时显著低于首次解析 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedAccessIsCheaperThanParsing` |

> 说明：全部 **36 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 27 / 27
- P2: 已覆盖 2 / 2
- **合计: 36 / 36**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（27 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 13+, iOS 17+
- 36 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitMCP
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
