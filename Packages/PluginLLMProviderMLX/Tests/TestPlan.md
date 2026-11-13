# TestPlan — PluginLLMProviderMLX

## 包概述

PluginLLMProviderMLX 的实现包，包含 14 个主要类型；当前测试覆盖 41 条用例。

平台: iOS 17+
测试文件: 11 个，用例总数: 41

核心组件（源码目录）:
- `LLMProviders/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MLXDownloadCacheIndex`
- `MLXDownloadManager`
- `MLXDownloadStatus`
- `MLXGenerationConsumer`
- `MLXModelDownloader`
- `MLXModelPaths`
- `MLXModelRegistration`
- `MLXProviderCatalog`
- `MLXProviderError`
- `MLXProviderPlugin`
- `MLXProviderPluginLocalStore`
- `MLXProviderRuntime`
- `MLXRuntime`
- `MLXSendableJSON`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MLXDownloadCacheIndex**（4 条）：由 `firstReadScansOnce`、`repeatedReadsDoNotRescan`、`invalidateForcesRescan` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXDownloadProgressScan**（3 条）：由 `repeatedStateReadsScanOnce`、`explicitRefreshRescans`、`stateUsesCachedSnapshot` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXGenerateToolSchema**（3 条）：由 `toolSchemaEnablesTypedArgumentParsing`、`noToolSchemaLeavesArgumentsUntyped`、`toolSchemaRejectsUndeclaredFunctionName` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXGenerationInfo**（5 条）：由 `infoEventProvidesTokenUsage`、`infoEventProvidesStopReason`、`infoEventDoesNotDisturbContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXGenerationRejection**（5 条）：由 `rejectionEventIsCaptured`、`rejectionNeverBecomesContent`、`firstRejectionIsKept` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXProviderPlugin**（6 条）：由 `registersAllLocalProviders`、`bootInjectsStorageDirectory`、`modelPathsUseInjectedDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXSendableJSONNumber**（5 条）：由 `zeroStaysNumeric`、`oneStaysNumeric`、`booleansStayBoolean` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXSendableJSON**（6 条）：由 `topLevelNullBecomesNil`、`nullInEnumStaysNil`、`nestedNullStaysNil` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXTokenizerLocalLoading**（2 条）：由 `localDirectoryLoadsTokenizer`、`missingTokenizerFileReportsConfigurationMissing` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MLXVLMFactoryLinking**（2 条）：由 `vlmTrampolineFactoryIsDiscoverable`、`factoryRegistryIsNotEmpty` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MLXDownloadCacheIndex | 首次读取才扫描一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstReadScansOnce` |
| 2 | MLXDownloadCacheIndex | 连续读取不再扫描 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `repeatedReadsDoNotRescan` |
| 3 | MLXDownloadCacheIndex | 作废后下次读取重新扫描 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidateForcesRescan` |
| 4 | MLXDownloadCacheIndex | 作废后读到的是最新磁盘状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidateReflectsLatestDiskState` |
| 5 | MLXDownloadProgressScan | 下载状态被反复读取时只扫描一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `repeatedStateReadsScanOnce` |
| 6 | MLXDownloadProgressScan | 显式刷新会重新扫描（磁盘可能已被外部改动） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitRefreshRescans` |
| 7 | MLXDownloadProgressScan | 扫描结果被缓存，状态里的模型集合与缓存大小一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateUsesCachedSnapshot` |
| 8 | MLXGenerateToolSchema | 工具 Schema 让响应解析按声明的类型转换参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemaEnablesTypedArgumentParsing` |
| 9 | MLXGenerateToolSchema | 没有工具 Schema 时参数不做类型转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noToolSchemaLeavesArgumentsUntyped` |
| 10 | MLXGenerateToolSchema | 工具 Schema 拒绝未声明的函数名 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolSchemaRejectsUndeclaredFunctionName` |
| 11 | MLXGenerationInfo | info 事件的 token 用量进入响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `infoEventProvidesTokenUsage` |
| 12 | MLXGenerationInfo | info 事件的停止原因进入响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `infoEventProvidesStopReason` |
| 13 | MLXGenerationInfo | info 事件不影响正文与工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `infoEventDoesNotDisturbContent` |
| 14 | MLXGenerationInfo | 没有 info 事件时用量保持为空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingInfoEventKeepsUsageNil` |
| 15 | MLXGenerationInfo | 非流式响应保留用量与停止原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingResponseKeepsUsage` |
| 16 | MLXProviderPlugin | 注册 5.16.0 的七个本地 MLX 供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAllLocalProviders` |
| 17 | MLXProviderPlugin | 启动时把存储目录注入模型根目录与运行时目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootInjectsStorageDirectory` |
| 18 | MLXProviderPlugin | 注入目录后 rootDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelPathsUseInjectedDirectory` |
| 19 | MLXProviderPlugin | 未注入目录时守卫拒绝回退到真实数据目录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `modelPathsRefuseWithoutInjectedDirectory` |
| 20 | MLXProviderPlugin | 注入目录后 settingsDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerRuntimeUseInjectedDirectory` |
| 21 | MLXProviderPlugin | 重置后清空注入目录，不再回退到真实数据目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerRuntimeResetClearsInjectedDirectory` |
| 22 | MLXSendableJSONNumber | JSON 数字 0 保持为数值而不是 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroStaysNumeric` |
| 23 | MLXSendableJSONNumber | JSON 数字 1 保持为数值而不是 true | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `oneStaysNumeric` |
| 24 | MLXSendableJSONNumber | JSON 布尔值仍然是布尔值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `booleansStayBoolean` |
| 25 | MLXSendableJSONNumber | Schema 里的 minimum/default 为 0 时保持数值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `schemaNumbersStayNumeric` |
| 26 | MLXSendableJSONNumber | 数组里的 0/1 也保持数值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `arrayNumbersStayNumeric` |
| 27 | MLXSendableJSON | 顶层 NSNull 转换为空值而不是字符串 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topLevelNullBecomesNil` |
| 28 | MLXSendableJSON | enum 里的 null 保持为空值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nullInEnumStaysNil` |
| 29 | MLXSendableJSON | 嵌套字典里的 null 保持为空值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedNullStaysNil` |
| 30 | MLXSendableJSON | 普通值不受影响 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `regularValuesUnchanged` |
| 31 | MLXSendableJSON | NSNumber 保留为数值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nsNumberStaysNumeric` |
| 32 | MLXSendableJSON | JSON null 绝不变成字符串 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nullNeverBecomesString` |
| 33 | MLXTokenizerLocalLoading | 本地模型目录能直接加载出 tokenizer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localDirectoryLoadsTokenizer` |
| 34 | MLXTokenizerLocalLoading | 本地目录缺少 tokenizer.json 时给出配置缺失错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingTokenizerFileReportsConfigurationMissing` |
| 35 | MLXVLMFactoryLinking | MLXVLM 的 trampoline factory 在运行时可被发现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `vlmTrampolineFactoryIsDiscoverable` |
| 36 | MLXVLMFactoryLinking | factory 注册表非空（LLM factory 至少可用） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `factoryRegistryIsNotEmpty` |
| 37 | MLXGenerationRejection | rejectedToolCall 事件必须被捕获而不是静默丢弃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectionEventIsCaptured` |
| 38 | MLXGenerationRejection | 被拒绝的原始输出不得进入正文或流式回调 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectionNeverBecomesContent` |
| 39 | MLXGenerationRejection | 多个拒绝事件保留第一个诊断 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRejectionIsKept` |
| 40 | MLXGenerationRejection | 错误描述携带原因与工具名且不泄漏原始输出 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `errorDescriptionCarriesSafeDiagnostics` |
| 41 | MLXGenerationRejection | 没有拒绝事件时保持为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `noRejectionKeepsNil` |

> 说明：全部 **41 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 30 / 30
- P2: 已覆盖 3 / 3
- **合计: 41 / 41**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（30 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: iOS 17+
- 41 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMProviderMLX
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
