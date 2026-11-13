# TestPlan — KitMCP

## 包概述

KitMCP Lumi 的 MCP（Model Context Protocol）客户端核心 Kit 包。 - 提供与 UI/插件无关的 MCP 客户端能力：服务器配置模型、传输层（stdio / Streamable HTTP）、 会话生命周期（initialize / listTools / callTool）、工具描述与调用结果模型。 - 底层使用官方 `modelcontextprotocol/swift-sdk`（精确锁版 `0.12.1`，官方分级 Tier 3）， 通过 `MCPServerServing` 薄抽象隔离，替换实现不影响上层调用方。 - 不依赖任何其他 Lumi 包；只被 `PluginMCP`（或宿主）依赖。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 21

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MCPImageContent`
- `MCPContentCodec`
- `MCPJSONValue`
- `MCPTransport`
- `MCPClientError`
- `MCPPreparedTransport`
- `MCPToolDescriptor`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MCPContentCodec**（7 条）：由 `textAndImage`、`resourceLink`、`errorFlag`、`structuredContentOnly`、`contentAndStructuredContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPJSONValue**（8 条）：由 `valueRoundTrip`、`foundationValue`、`fromFoundation`、`jsonZeroAndOneStayNumbers`、`mcpArgumentsPreserveJSONZeroAndOne`、`nativeSwiftBoolAndNumbersUnchanged` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPServerSession**（6 条）：由 `listAndCallTool`、`errorResult`、`notConnected`、`structuredContentOnlyResult`、`contentAndStructuredContentResult` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MCPContentCodec | 文本与图片混合编码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textAndImage` |
| 2 | MCPContentCodec | resourceLink 以文本标记呈现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resourceLink` |
| 3 | MCPContentCodec | isError 透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorFlag` |
| 4 | MCPJSONValue | MCP Value 往返转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueRoundTrip` |
| 5 | MCPJSONValue | foundationValue 产生 JSON 兼容对象 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foundationValue` |
| 6 | MCPJSONValue | fromFoundation 含不支持的值时整体返回 nil（不静默丢参数） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fromFoundation` |
| 7 | MCPJSONValue | jsonString 输出规范 JSON | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `jsonString` |
| 8 | MCPJSONValue | MCPValueCoding 把上层参数字典转为 MCP Value | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mcpArguments` |
| 9 | MCPServerSession | 连接后列出工具并调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listAndCallTool` |
| 10 | MCPServerSession | 服务器报错时 isError 透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorResult` |
| 11 | MCPServerSession | 未连接时调用抛 notConnected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `notConnected` |
| 12 | MCPServerSession | 重复连接是幂等的 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `connectIdempotent` |
| 13 | MCPJSONValue | JSON 数字 0/1 不得被误判为布尔（**#1154**） | JSONSerialization 解析出的 NSNumber 数字叶子 | fromFoundation 转换含 0/1/2/true/false 与嵌套的对象 | 0/1/2 为 .int，true/false 为 .bool，嵌套数组与对象同样保真 | P0 | ✅ 已覆盖 | `jsonZeroAndOneStayNumbers` |
| 14 | MCPJSONValue | MCP 调用参数中的 JSON 0/1 以数字送达（**#1154**） | JSONSerialization 解析出的参数字典 | MCPValueCoding.mcpArguments | count/mode 为 Value.int(0) 与 .int(1) | P1 | ✅ 已覆盖 | `mcpArgumentsPreserveJSONZeroAndOne` |
| 15 | MCPJSONValue | 原生 Swift 布尔与数字的桥接行为不变（**#1154**） | 原生 Bool/Int 字面量 | fromFoundation 与 jsonString | 布尔仍为布尔、数字仍为数字，输出 {"count":0} | P1 | ✅ 已覆盖 | `nativeSwiftBoolAndNumbersUnchanged` |
| 16 | MCPContentCodec | 仅 structuredContent 序列化为 JSON 文本（**#180**） | 无常规 content、仅 structuredContent | encode 传入 structuredContent 对象 | text 为 {"answer":42}，images 空，isError 透传 | P0 | ✅ 已覆盖 | `structuredContentOnly` |
| 17 | MCPContentCodec | content 与 structuredContent 同时保留（**#180**） | content 文本与 structuredContent 并存 | encode 同时传入两者 | text 为 hello 换行 {"answer":42} | P0 | ✅ 已覆盖 | `contentAndStructuredContent` |
| 18 | MCPContentCodec | 嵌套 structuredContent 仍是合法 JSON 且内容保真（**#180**） | 含数组与嵌套对象的 structuredContent | encode 后用 JSONSerialization 解析 text | 解析成功，items 为 [1,2]，meta.ok 为 true | P1 | ✅ 已覆盖 | `nestedStructuredContentIsValidJSON` |
| 19 | MCPContentCodec | structuredContent 为 nil 时文本编码不变（**#180**） | structuredContent 为 nil | encode 仅传入文本 content | text 仍为 hi，不受新参数影响 | P1 | ✅ 已覆盖 | `structuredContentNilPreservesText` |
| 20 | MCPServerSession | 仅返回 structuredContent 的成功结果序列化为 JSON 文本（**#180**） | InMemory mock 服务器仅返回 structuredContent | connect 后 callTool structuredOnly | text 为 {"answer":42}，isError false，images 空 | P0 | ✅ 已覆盖 | `structuredContentOnlyResult` |
| 21 | MCPServerSession | content 与 structuredContent 同时返回时两者都保留（**#180**） | InMemory mock 服务器返回文本与 structuredContent | connect 后 callTool structuredWithText | text 为 hello 换行 {"answer":42}，isError false | P0 | ✅ 已覆盖 | `contentAndStructuredContentResult` |

> 说明：全部 **21 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 15 / 15
- P2: 已覆盖 0 / 0
- **合计: 21 / 21**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（15 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 21 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
