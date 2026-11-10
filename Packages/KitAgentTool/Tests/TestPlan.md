# TestPlan — KitAgentTool

## 包概述

KitAgentTool 可复用的 Agent 工具协议与运行时模型。定义 LLM 工具调用、参数解析、权限风险、取消上下文与多语言 schema，供宿主应用与插件共享。

平台: macOS 14+, iOS 17+
测试文件: 9 个，用例总数: 93

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentPendingImageAttachment`
- `CommandRiskLevel`
- `ImageAttachment`
- `KitAgentToolLocalization`
- `LanguagePreference`
- `SuperAgentTool`
- `ToolArgument`
- `ToolCall`
- `ToolCallAuthorizationState`
- `ToolCallInteractionState`
- `ToolContextProviding`
- `ToolError`
- `ToolExecutionCapability`
- `ToolExecutionOutputStream`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentPendingImageAttachment**（5 条）：由 `idReturnsEmbeddedIdentifier`、`equalityComparesIdMimeTypeAndData`、`equalityFailsOnDifferentData` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CodableCoverage**（4 条）：由 `displayNameCoversAllCases`、`answerIsNilWhileWaiting`、`encodeDisplayDescription` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CoreModel**（23 条）：由 `initStoresAllFields`、`initDefaultsAuthorizationStateToPending`、`codableRoundTripPreservesExplicitAuthorizationState` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LanguagePreference**（7 条）：由 `chineseLocaleMapsToChinese`、`englishLocaleMapsToEnglish`、`currentIsNotNilCase` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolError**（5 条）：由 `toolNotFoundIncludesToolName`、`toolExecutionFailedIncludesUnderlyingDescription`、`toolNotFoundDescription` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolCallContextArguments**（7 条）：由 `replacesOnlyRequestedKey`、`invalidJSONReturnsOriginal`、`existentialDispatchUsesToolDeclaration` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolExecutionContext**（2 条）：由 `legacyToolUsesDefaultContextImplementation`、`contextAwareToolReportsOutputAndProgress` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolImageResultCodec**（7 条）：由 `encodePrefixesMarkerAndRoundTripsContent`、`decodeReturnsNilForPlainTextResult`、`decodeReturnsNilForInvalidJSONPayload` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UncoveredLogic**（14 条）：由 `defaultDescriptionUsesEnglishVariant`、`defaultInputSchemaUsesEnglishVariant`、`defaultExecuteThrowsExecutionFailed` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentPendingImageAttachment | idReturnsEmbeddedIdentifier | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idReturnsEmbeddedIdentifier` |
| 2 | AgentPendingImageAttachment | equalityComparesIdMimeTypeAndData | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalityComparesIdMimeTypeAndData` |
| 3 | AgentPendingImageAttachment | equalityFailsOnDifferentData | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalityFailsOnDifferentData` |
| 4 | AgentPendingImageAttachment | equalityFailsOnDifferentMimeType | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalityFailsOnDifferentMimeType` |
| 5 | AgentPendingImageAttachment | equalityFailsOnDifferentId | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalityFailsOnDifferentId` |
| 6 | CodableCoverage | displayName returns localized names for every case | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayNameCoversAllCases` |
| 7 | CodableCoverage | interaction state answer is nil while waiting | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `answerIsNilWhileWaiting` |
| 8 | CodableCoverage | ToolCall encodes optional display description when present | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodeDisplayDescription` |
| 9 | CodableCoverage | ToolCall omits display description when absent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `omitDisplayDescription` |
| 10 | CoreModel | initStoresAllFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initStoresAllFields` |
| 11 | CoreModel | initDefaultsAuthorizationStateToPending | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `initDefaultsAuthorizationStateToPending` |
| 12 | CoreModel | codableRoundTripPreservesExplicitAuthorizationState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTripPreservesExplicitAuthorizationState` |
| 13 | CoreModel | decodeDefaultsMissingAuthorizationStateToPending | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `decodeDefaultsMissingAuthorizationStateToPending` |
| 14 | CoreModel | encodeOmitsPendingAuthorizationState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodeOmitsPendingAuthorizationState` |
| 15 | CoreModel | encodeIncludesNonPendingAuthorizationState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodeIncludesNonPendingAuthorizationState` |
| 16 | CoreModel | equatableComparesAllFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equatableComparesAllFields` |
| 17 | CoreModel | displayNamesAreNonEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayNamesAreNonEmpty` |
| 18 | CoreModel | onlyPendingNeedsAuthorizationPrompt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onlyPendingNeedsAuthorizationPrompt` |
| 19 | CoreModel | codableRoundTripPreservesAllCases | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTripPreservesAllCases` |
| 20 | CoreModel | onlyHighRequiresPermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onlyHighRequiresPermission` |
| 21 | CoreModel | displayNamesAreNonEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayNamesAreNonEmpty` |
| 22 | CoreModel | reasonIsNilOnlyForSafe | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasonIsNilOnlyForSafe` |
| 23 | CoreModel | codableRoundTripPreservesRawValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTripPreservesRawValues` |
| 24 | CoreModel | idMatchesRawValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idMatchesRawValue` |
| 25 | CoreModel | systemPromptDescriptionMentionsLanguage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `systemPromptDescriptionMentionsLanguage` |
| 26 | CoreModel | codableRoundTripPreservesCases | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTripPreservesCases` |
| 27 | CoreModel | storesArbitraryValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storesArbitraryValue` |
| 28 | CoreModel | initDefaultsIdWhenNotProvided | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `initDefaultsIdWhenNotProvided` |
| 29 | CoreModel | equalityIgnoresDataButComparesIdAndMimeType | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalityIgnoresDataButComparesIdAndMimeType` |
| 30 | CoreModel | codableRoundTripPreservesFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTripPreservesFields` |
| 31 | CoreModel | codableRoundTripPreservesFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTripPreservesFields` |
| 32 | CoreModel | codableRoundTripPreservesEmbeddedResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTripPreservesEmbeddedResult` |
| 33 | LanguagePreference | chineseLocaleMapsToChinese | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chineseLocaleMapsToChinese` |
| 34 | LanguagePreference | englishLocaleMapsToEnglish | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `englishLocaleMapsToEnglish` |
| 35 | LanguagePreference | currentIsNotNilCase | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `currentIsNotNilCase` |
| 36 | LanguagePreference | localeIdentifierRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localeIdentifierRoundTrip` |
| 37 | LanguagePreference | allCasesHaveUniqueIds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allCasesHaveUniqueIds` |
| 38 | LanguagePreference | codableRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTrip` |
| 39 | LanguagePreference | systemPromptDescriptionMatchesLanguage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `systemPromptDescriptionMatchesLanguage` |
| 40 | ToolError | toolNotFoundIncludesToolName | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNotFoundIncludesToolName` |
| 41 | ToolError | toolExecutionFailedIncludesUnderlyingDescription | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolExecutionFailedIncludesUnderlyingDescription` |
| 42 | ToolError | toolNotFoundDescription | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNotFoundDescription` |
| 43 | ToolError | executionFailedDescription | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executionFailedDescription` |
| 44 | ToolError | permissionDeniedDescription | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `permissionDeniedDescription` |
| 45 | ToolExecutionContext | 旧工具通过默认 Context 实现仍返回原文本结果 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `legacyToolUsesDefaultContextImplementation` |
| 46 | ToolExecutionContext | 新工具可以通过 Context 上报输出和进度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextAwareToolReportsOutputAndProgress` |
| 47 | ToolImageResultCodec | encodePrefixesMarkerAndRoundTripsContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodePrefixesMarkerAndRoundTripsContent` |
| 48 | ToolImageResultCodec | decodeReturnsNilForPlainTextResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodeReturnsNilForPlainTextResult` |
| 49 | ToolImageResultCodec | decodeReturnsNilForInvalidJSONPayload | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `decodeReturnsNilForInvalidJSONPayload` |
| 50 | ToolImageResultCodec | decodeSkipsImagesWithInvalidBase64 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `decodeSkipsImagesWithInvalidBase64` |
| 51 | ToolImageResultCodec | encodeHandlesMultipleImages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodeHandlesMultipleImages` |
| 52 | ToolImageResultCodec | encodeWithEmptyImagesStillRoundTripsContent | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `encodeWithEmptyImagesStillRoundTripsContent` |
| 53 | ToolImageResultCodec | encodePreservesUnicodeContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodePreservesUnicodeContent` |
| 54 | UncoveredLogic | defaultDescriptionUsesEnglishVariant | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultDescriptionUsesEnglishVariant` |
| 55 | UncoveredLogic | defaultInputSchemaUsesEnglishVariant | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultInputSchemaUsesEnglishVariant` |
| 56 | UncoveredLogic | defaultExecuteThrowsExecutionFailed | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultExecuteThrowsExecutionFailed` |
| 57 | UncoveredLogic | defaultExecuteErrorMessageMentionsTool | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultExecuteErrorMessageMentionsTool` |
| 58 | UncoveredLogic | defaultExecuteResultWrapsContent | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultExecuteResultWrapsContent` |
| 59 | UncoveredLogic | defaultExecuteResultPropagatesErrors | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultExecuteResultPropagatesErrors` |
| 60 | UncoveredLogic | emptyLocaleFallsBackToIdentifierAndMapsToEnglish | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyLocaleFallsBackToIdentifierAndMapsToEnglish` |
| 61 | UncoveredLogic | answeredStateExposesAnswer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `answeredStateExposesAnswer` |
| 62 | UncoveredLogic | codableRoundTripPreservesBothCases | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTripPreservesBothCases` |
| 63 | UncoveredLogic | decodeLegacyJSONWithOnlyContentAppliesDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `decodeLegacyJSONWithOnlyContentAppliesDefaults` |
| 64 | UncoveredLogic | roundTripPreservesDurationAwaitingAndInteractionState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripPreservesDurationAwaitingAndInteractionState` |
| 65 | UncoveredLogic | encodeOmitsDefaultOptionalFields | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `encodeOmitsDefaultOptionalFields` |
| 66 | UncoveredLogic | returnsKeyItselfWhenTranslationMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsKeyItselfWhenTranslationMissing` |
| 67 | UncoveredLogic | knownKeyResolvesFromModuleCatalog | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `knownKeyResolvesFromModuleCatalog` |
| 68 | ToolArgumentNumber | 整数原样返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsPlainInt` |
| 69 | ToolArgumentNumber | 范围内的 Double 转换成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsFiniteDouble` |
| 70 | ToolArgumentNumber | 超出 Int 范围的 Double 返回 nil 而不是崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsOutOfRangeDouble` |
| 71 | ToolArgumentNumber | 非有限 Double 返回 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsNonFiniteDouble` |
| 72 | ToolArgumentNumber | 数字字符串可转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsNumericString` |
| 73 | ToolArgumentNumber | 非数值类型返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsOtherTypes` |
| 74 | ToolArgumentNumber | int(fromDouble:) 对边界值安全 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `convertsBoundaryDoubles` |
| 75 | ToolArgumentNumber | 可表示但超范围的值被钳制 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsOutOfRangeValues` |
| 76 | ToolArgumentNumber | 无法表示的值退回默认值而不是被当作超大值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `unrepresentableValuesFallBackToDefault` |
| 77 | ToolArgumentNumber | 无法表示的值退回默认值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fallsBackToDefault` |
| 78 | ToolArgumentNumber | 字典扩展读取整型参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dictionaryExtensionReadsIntegers` |
| 79 | ToolArgumentNumber | 字典扩展读取并钳制整型参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dictionaryExtensionClampsIntegers` |
| 80 | ToolInteractionPayload | 权限载荷同时满足两个谓词 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `permissionPayloadSatisfiesBothPredicates` |
| 81 | ToolInteractionPayload | 计算机使用载荷是授权而非权限 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `computerUsePayloadIsAuthorizationButNotPermission` |
| 82 | ToolInteractionPayload | 交互载荷不是权限请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `interactionPayloadIsNotPermissionRequest` |
| 83 | ToolInteractionPayload | 纯文本不是结构化载荷 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `plainTextIsNotStructuredPayload` |
| 84 | ToolInteractionPayload | 解码兼容大写旧键 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesLegacyUppercaseKey` |
| 85 | ToolInteractionPayload | 编码后的键为小写 d | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodedKeyIsLowercaseD` |
| 86 | ToolInteractionPayload | 往返转换保留字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripPreservesValues` |
| 87 | ToolCallContextArguments | 只替换声明的键，其余参数保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replacesOnlyRequestedKey` |
| 88 | ToolCallContextArguments | 没有声明要移除的键时原样返回 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyOmissionSetReturnsOriginal` |
| 89 | ToolCallContextArguments | 参数里没有目标键时原样返回 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `missingKeyReturnsOriginal` |
| 90 | ToolCallContextArguments | 非法 JSON 原样返回，不破坏历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `invalidJSONReturnsOriginal` |
| 91 | ToolCallContextArguments | 非对象 JSON 原样返回 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonObjectJSONReturnsOriginal` |
| 92 | ToolCallContextArguments | 裁剪结果仍是合法 JSON 对象 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scrubbedOutputRemainsValidJSONObject` |
| 93 | ToolCallContextArguments | 存在类型上调用也命中工具自己的声明 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `existentialDispatchUsesToolDeclaration` |

> 说明：全部 **93 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 66 / 66
- P2: 已覆盖 19 / 19
- **合计: 93 / 93**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（66 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（19 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 86 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitAgentTool
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
