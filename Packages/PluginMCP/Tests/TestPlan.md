# TestPlan — PluginMCP

## 包概述

PluginMCP 让 Lumi 成为 **Cursor 式通用 MCP 客户端**：在设置中添加"MCP 服务器"入口，用户可自由添加 / 配置任意 MCP 服务器；服务器暴露的工具自动桥接进 Agent 工具列表，随会话一起审批与执行。 ## 能力 - **通用 MCP 客户端**：stdio（本地子进程）与 Streamable HTTP 两种传输； - **Cursor 式设置页**：服务器列表、添加/编辑表单、内置模板（Xcode native 等）、工具清单与风险徽标、全局开关； - **工具桥接**：MCP 工具 → `SuperAgentTool`，注册进 `ToolManagerProviding`（归属本插件），LLM 可直接调用； - **风险分级**：默认分级表 + 未知工具默认 `high` + 单工具风险覆盖 + 注解启发（`readOnlyHint` / `destructiveHint`）； - **安全默认**：第三方服务器 = 本机任意代码执行面，添加时强提示；默认不自动连接。

平台: macOS 14+
测试文件: 10 个，用例总数: 65

核心组件（源码目录）:
- `Managers/`
- `Models/`
- `Providers/`
- `Support/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MCPPlugin`
- `MCPServerConnectionState`
- `MCPServerRegistry`
- `MCPPermissionPolicy`
- `MCPToolAdapter`
- `MCPServerContributor`
- `MCPText`
- `MCPArgumentsCodec`
- `MCPSettingsView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MCPLocalization**（3 条）：由 `zhHansResolves`、`connectionStateKeys`、`miscKeys` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPPermissionPolicy**（6 条）：由 `xcodeExactTable`、`unknownDefault`、`overrideWins` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPPermissionServerScope**（8 条）：由 `foreignDestructiveSameNameIsHigh`、`rejectsForeignCommands`、`foreignAdapterDestructiveSameName` 等用例锁定 Xcode 精确规则的服务器身份边界（#530）；改动该模块时优先跑对应测试文件。
- **MCPPluginBoot**（2 条）：由 `bootResolvesPluginDataDirectory`、`refusesWithoutStorageProvider` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPPluginShutdown**（1 条）：由 `shutdownDisconnectsSessions` 用例锁定；改动该模块时优先跑对应测试文件。
- **MCPServerEditValidation**（5 条）：由 `httpAllowsEmptyCommand`、`httpRequiresURL`、`stdioRequiresCommand` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPServerRegistry**（13 条）：由 `seedsPreset`、`crud`、`persistenceRoundTrip`、`corruptFileIsPreservedOnLoad` 等用例锁定（含 #531 解码失败不得清空写回）；改动该模块时优先跑对应测试文件。
- **MCPToolAdapter**（12 条）：由 `bridgeShape`、`riskLevels`、`executionCapability` 等用例锁定（含 #178 取消透传）；改动该模块时优先跑对应测试文件。
- **MCPArgumentsCodec**（15 条）：由 `roundTripPreservesArgumentWithSpaces`、`parseDoubleQuotedInputKeepsSpaces`、`emptyArgumentRoundTrips` 等用例锁定；参数编辑框的拼接/拆分必须可逆（`parse(join(args)) == args`），含空格/引号/反斜杠的单个参数不得被拆坏或丢失（#534）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MCPLocalization | xcstrings 中文翻译命中（简体） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zhHansResolves` |
| 2 | MCPLocalization | 连接状态文案走本地化 key（不再硬编码中文） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `connectionStateKeys` |
| 3 | MCPLocalization | 工具计数与风险等级文案翻译 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `miscKeys` |
| 4 | MCPPermissionPolicy | Xcode 精确规则表逐项匹配（本机 27.0 实测 54 工具） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `xcodeExactTable` |
| 5 | MCPPermissionPolicy | 未知工具默认 high，可配置 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownDefault` |
| 6 | MCPPermissionPolicy | 用户覆盖优先于一切规则 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overrideWins` |
| 7 | MCPPermissionPolicy | 注解启发：破坏性优先 high，只读 safe | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `annotations` |
| 8 | MCPPermissionPolicy | 名称关键词启发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `heuristics` |
| 9 | MCPPermissionPolicy | 危险词优先于只读词（同一名称含两个特征） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dangerBeforeRead` |
| 10 | MCPPluginBoot | 启动时从 StorageProviding 解析插件数据目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootResolvesPluginDataDirectory` |
| 11 | MCPPluginBoot | 未注册 StorageProviding 时守卫拒绝回退到真实数据目录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refusesWithoutStorageProvider` |
| 12 | MCPServerEditValidation | HTTP 传输允许空 command | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `httpAllowsEmptyCommand` |
| 13 | MCPServerEditValidation | HTTP 传输仍要求 URL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpRequiresURL` |
| 14 | MCPServerEditValidation | stdio 传输仍要求 command | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stdioRequiresCommand` |
| 15 | MCPServerEditValidation | 两种传输都要求名称 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nameRequiredForBothTransports` |
| 16 | MCPServerEditValidation | 完整的 stdio 配置通过校验 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stdioValidConfigurationPasses` |
| 17 | MCPServerRegistry | 贡献的内置预设（Xcode 与 GitHub）以禁用态落库 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `seedsPreset` |
| 18 | MCPServerRegistry | CRUD：新增 / 更新 / 删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crud` |
| 19 | MCPServerRegistry | 持久化往返：重建实例后状态一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistenceRoundTrip` |
| 20 | MCPServerRegistry | 重复初始化不重复写入贡献预设 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `noDuplicateSeed` |
| 21 | MCPServerRegistry | 加载时按 id 去重（自愈历史重复数据） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadDeduplicatesById` |
| 22 | MCPServerRegistry | 更新时替换全部同 id 条目，不产生重复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `updateReplacesAllSameId` |
| 23 | MCPServerRegistry | 模拟 boot 序列：先贡献 Xcode 再贡献 GitHub，两个都应 seed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `simulateBootContributions` |
| 24 | MCPToolAdapter | 桥接命名空间与 schema 直通 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bridgeShape` |
| 25 | MCPToolAdapter | 风险分级：策略判定与用户覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskLevels` |
| 26 | MCPToolAdapter | 只读工具声明并行，其余串行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executionCapability` |
| 27 | MCPToolAdapter | executeResult 调用回传文本结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeText` |
| 28 | MCPToolAdapter | 图片结果映射为 ImageAttachment | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeImage` |
| 29 | MCPToolAdapter | 未连接会话调用报错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `notConnected` |
| 30 | MCPToolAdapter | mcpbridge 已知错误翻译为可操作提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `friendlyErrorHints` |
| 31 | MCPToolAdapter | 适配器提供规范化 schema 文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providesNormalizedSchemaText` |
| 32 | MCPToolAdapter | 适配器实现 NormalizedSchemaProviding 协议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conformsToNormalizedSchemaProviding` |
| 33 | MCPToolAdapter | 规范化文本与直接序列化结果一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedTextMatchesDirectSerialization` |
| 34 | MCPPluginShutdown | 关闭时异步清理强引用 manager，确实断开会话（回归 #141） | 已注入可观察会话 | 调用 onShutdown 并等待清理 | disconnect 恰好被调用一次 | P0 | ✅ 已覆盖 | `shutdownDisconnectsSessions` |
| 35 | MCPServerRegistry | 删除的内置模板重启后不再被自动 seed（回归 #295） | 贡献 Xcode 模板后删除它 | 同目录同贡献者重建注册表 | 重启后 Xcode 不再出现 | P1 | ✅ 已覆盖 | `deletedBuiltInTemplateStaysDeletedAcrossRestart` |
| 36 | MCPServerRegistry | 删除一个内置模板不影响其他内置模板的 seed | 贡献 Xcode 与 GitHub 后删除 Xcode | 同目录同贡献者重建注册表 | Xcode 不再出现，GitHub 仍在 | P1 | ✅ 已覆盖 | `deletingOneTemplateDoesNotBlockOthers` |
| 37 | MCPPermissionServerScope | foreign 服务器的同名破坏性工具按 destructiveHint 判 high，不继承精确表（#530） | 非 Xcode 服务器暴露 XcodeRead 等并声明 destructiveHint | 调用 policy.level（isXcodeNativeServer 默认 false） | 一律 high，不得继承 safe/low/medium | P0 | ✅ 已覆盖 | `foreignDestructiveSameNameIsHigh` |
| 38 | MCPPermissionServerScope | foreign 服务器即使只读同名工具也不套用精确表，走注解/启发式（#530） | 非 Xcode 服务器暴露 RenderPreview/XcodeRead/XcodeMakeDir | 调用 policy.level | 按注解/启发式/默认分级，不继承精确表 | P0 | ✅ 已覆盖 | `foreignReadOnlySameNameUsesHintsNotTable` |
| 39 | MCPPermissionServerScope | Xcode 原生服务器仍套用精确表 | isXcodeNativeServer=true | 调用 policy.level | 精确表分级保持不变 | P1 | ✅ 已覆盖 | `nativeXcodeKeepsExactTable` |
| 40 | MCPPermissionServerScope | 用户覆盖在两种服务器身份下都优先 | 设置 override | 调用 policy.level | override 优先于精确表与注解 | P1 | ✅ 已覆盖 | `overrideWinsRegardlessOfServer` |
| 41 | MCPPermissionServerScope | xcrun mcpbridge 及其路径变体被识别为 Xcode 原生桥 | 各种 xcrun/mcpbridge 命令配置 | 调用 isXcodeNativeServer | 返回 true | P1 | ✅ 已覆盖 | `detectsXcodeNativeBridge` |
| 42 | MCPPermissionServerScope | foreign 命令不被识别为 Xcode 原生桥（#530） | npx/docker/echo 等命令，或仅名称含 Xcode | 调用 isXcodeNativeServer | 返回 false，不得误认身份 | P0 | ✅ 已覆盖 | `rejectsForeignCommands` |
| 43 | MCPPermissionServerScope | foreign 适配器暴露同名破坏性工具时判 high 且串行（#530） | 以 foreign 命令配置构造适配器，工具名 XcodeRead+destructive | 读取 permissionRiskLevel/executionCapability | high 且 serialSideEffect | P0 | ✅ 已覆盖 | `foreignAdapterDestructiveSameName` |
| 44 | MCPPermissionServerScope | Xcode 原生适配器的只读同名工具仍判 safe 且可并行 | 以 xcrun mcpbridge 配置构造适配器，XcodeRead+readOnly | 读取 permissionRiskLevel/executionCapability | safe 且 parallelReadOnly | P1 | ✅ 已覆盖 | `nativeAdapterReadOnlySameName` |
| 45 | MCPServerRegistry | 解码失败保留原文件，不被 seed 覆盖（回归 #531） | mcp-servers.json 为合法 JSON 但类型不符 | 贡献 Xcode 模板后构建注册表 | loadFailed 置位，原文件字节不变 | P0 | ✅ 已覆盖 | `corruptFileIsPreservedOnLoad` |
| 46 | MCPServerRegistry | 解码失败后 CRUD 也不覆盖原文件（回归 #531） | mcp-servers.json 为截断/损坏字节 | 加载后执行 add/update/remove | loadFailed 置位，原文件字节不变 | P0 | ✅ 已覆盖 | `corruptFileSurvivesCRUD` |
| 47 | MCPServerRegistry | 文件缺失视为首次运行，允许 seed 落库 | 数据目录无 mcp-servers.json | 贡献 Xcode 模板后构建注册表 | loadFailed 不置位，seed 落库且重启后仍在 | P1 | ✅ 已覆盖 | `missingFileAllowsSeed` |
| 48 | MCPServerRegistry | 合法文件加载不置 loadFailed | 已写入合法配置 | 同目录重建注册表 | loadFailed 不置位，配置完整恢复 | P1 | ✅ 已覆盖 | `validFileDoesNotSetLoadFailed` |
| 49 | MCPToolAdapter | CancellationError 必须原样透传，不得包装为执行失败（**#178**） | 会话替身抛 CancellationError | 调用 executeResult | 抛出 CancellationError 而非 ToolExecutionError | P0 | ✅ 已覆盖 | `cancellationErrorPassesThrough` |
| 50 | MCPToolAdapter | 调用返回后任务已取消时不得产出成功结果（**#178**） | 任务先取消再进入 executeResult，会话替身正常回包 | 等待任务结果 | 抛出 CancellationError，不落成功结果 | P0 | ✅ 已覆盖 | `cancelledAfterCallReturnsThrowsCancellation` |
| 51 | MCPArgumentsCodec | 含空格的参数经拼接→拆分往返后边界不变（**回归 #534**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `roundTripPreservesArgumentWithSpaces` |
| 52 | MCPArgumentsCodec | 含空格的参数拼接时被双引号包裹 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `joinQuotesArgumentWithSpaces` |
| 53 | MCPArgumentsCodec | 双引号输入拆分后保留内部空格 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `parseDoubleQuotedInputKeepsSpaces` |
| 54 | MCPArgumentsCodec | 单引号输入拆分后保留内部空格 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parseSingleQuotedInputKeepsSpaces` |
| 55 | MCPArgumentsCodec | 无特殊字符的参数拼接/拆分原样不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `plainArgumentsAreUnchanged` |
| 56 | MCPArgumentsCodec | 空字符串参数往返后仍是一个空参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyArgumentRoundTrips` |
| 57 | MCPArgumentsCodec | 参数内嵌双引号往返不丢失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `embeddedDoubleQuoteRoundTrips` |
| 58 | MCPArgumentsCodec | 参数内嵌反斜杠往返不丢失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `embeddedBackslashRoundTrips` |
| 59 | MCPArgumentsCodec | 参数内嵌单引号往返不丢失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `embeddedSingleQuoteRoundTrips` |
| 60 | MCPArgumentsCodec | 参数内部的制表符/换行/空格被保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `whitespaceInsideArgumentIsPreserved` |
| 61 | MCPArgumentsCodec | 空文本与纯空白文本拆不出参数 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyAndWhitespaceTextYieldNoArguments` |
| 62 | MCPArgumentsCodec | 空数组拼接为空文本 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyArrayJoinsToEmptyText` |
| 63 | MCPArgumentsCodec | 相邻引号片段拼接为同一个参数 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `adjacentQuotedSegmentsConcatenate` |
| 64 | MCPArgumentsCodec | 引号外的反斜杠转义空格 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `backslashEscapesSpaceOutsideQuotes` |
| 65 | MCPArgumentsCodec | 多组参数语料往返不变量恒成立 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `roundTripHoldsForVariedCorpus` |

> 说明：全部 **65 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> 变异验证（#178）：移除适配器的 `catch is CancellationError` 透传与回包后的 `Task.checkCancellation()` 后，两条新用例分别失败（取消被包装成执行失败 / 产出成功结果）；恢复后重新通过。
> 变异验证（#534）：① 去掉 join 的引号包裹（含空格参数原样输出）→ `joinQuotesArgumentWithSpaces` 失败；② parse 把双引号当普通字符（不进入引号态）→ `parseDoubleQuotedInputKeepsSpaces` 失败；③ 用 `current.isEmpty` 取代 `hasToken` 标志（空引号 token 被丢弃）→ `emptyArgumentRoundTrips` 失败；恢复后重新通过。

## 覆盖率统计

- P0: 已覆盖 17 / 17
- P1: 已覆盖 41 / 41
- P2: 已覆盖 7 / 7
- **合计: 65 / 65**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（17 条）
- **P1**: 其余功能性用例（41 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+
- 65 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMCP
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
