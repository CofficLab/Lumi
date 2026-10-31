# TestPlan — KitEditorLanguageRuntime

## 包概述

KitEditorLanguageRuntime `KitEditorLanguageRuntime` 是 Lumi 项目中负责编辑器语言运行时能力的 Kit package，提供语言识别、grammar/query 管理及 Tree-sitter 运行时支持。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 30

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `LanguageGrammarProviding`
- `EditorLanguageContext`
- `EditorLanguageDescriptor`
- `EditorLanguageRuntimeLocalization`
- `LanguageDetection`
- `LanguageQueryRegistry`
- `LanguageRegistry`
- `LanguageResourceLocator`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **LanguageDetection**（13 条）：由 `urlExtensionWinsFirst`、`unknownExtensionFallsBackToShebang`、`shebangAliasWithVersionSuffix` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LanguageRegistry**（2 条）：由 `testPlainTextDetectionForUnknownExtension`、`testRegistersDescriptorAndDetectsExtension` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LanguageRuntimeCoverage**（15 条）：由 `testContextAccessorsForwardToDescriptor`、`testPlainTextContextDefaults`、`testDescriptorDefaultsAndRangeComment` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | LanguageDetection | urlExtensionWinsFirst | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `urlExtensionWinsFirst` |
| 2 | LanguageDetection | unknownExtensionFallsBackToShebang | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownExtensionFallsBackToShebang` |
| 3 | LanguageDetection | shebangAliasWithVersionSuffix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shebangAliasWithVersionSuffix` |
| 4 | LanguageDetection | modelineVimStyle | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelineVimStyle` |
| 5 | LanguageDetection | modelineEmacsStyleFromSuffix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelineEmacsStyleFromSuffix` |
| 6 | LanguageDetection | modelineDoesNotMatchKeyInsideWords | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelineDoesNotMatchKeyInsideWords` |
| 7 | LanguageDetection | fileNameMatchIsCaseInsensitive | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileNameMatchIsCaseInsensitive` |
| 8 | LanguageDetection | shebangMatchingIsCaseInsensitiveOnAliases | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shebangMatchingIsCaseInsensitiveOnAliases` |
| 9 | LanguageDetection | noSignalsYieldsPlainText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noSignalsYieldsPlainText` |
| 10 | LanguageDetection | extensionMatchIsCaseInsensitiveOnFileExtension | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extensionMatchIsCaseInsensitiveOnFileExtension` |
| 11 | LanguageDetection | shebangDoesNotMatchSubstringInsideTokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shebangDoesNotMatchSubstringInsideTokens` |
| 12 | LanguageDetection | shebangMatchesVersionedInterpreter | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shebangMatchesVersionedInterpreter` |
| 13 | LanguageDetection | modelineVimMarkerRequiresWordBoundary | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelineVimMarkerRequiresWordBoundary` |
| 14 | LanguageRegistry | testPlainTextDetectionForUnknownExtension | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPlainTextDetectionForUnknownExtension` |
| 15 | LanguageRegistry | testRegistersDescriptorAndDetectsExtension | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRegistersDescriptorAndDetectsExtension` |
| 16 | LanguageRuntimeCoverage | testContextAccessorsForwardToDescriptor | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContextAccessorsForwardToDescriptor` |
| 17 | LanguageRuntimeCoverage | testPlainTextContextDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testPlainTextContextDefaults` |
| 18 | LanguageRuntimeCoverage | testDescriptorDefaultsAndRangeComment | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDescriptorDefaultsAndRangeComment` |
| 19 | LanguageRuntimeCoverage | testRegistryContextLookupAndDuplicateRegister | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRegistryContextLookupAndDuplicateRegister` |
| 20 | LanguageRuntimeCoverage | testResourceLocatorFallsBackToFirstCandidate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResourceLocatorFallsBackToFirstCandidate` |
| 21 | LanguageRuntimeCoverage | testQueryRegistryCachesAndRejectsEmptyInput | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testQueryRegistryCachesAndRejectsEmptyInput` |
| 22 | LanguageRuntimeCoverage | testBundledGrammarProviderDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testBundledGrammarProviderDefaults` |
| 23 | LanguageRuntimeCoverage | testLocalizationForwardsToLumiLocalization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLocalizationForwardsToLumiLocalization` |
| 24 | LanguageRuntimeCoverage | testFakeProviderPathThroughTreeSitterAndHighlightQuery | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFakeProviderPathThroughTreeSitterAndHighlightQuery` |
| 25 | LanguageRuntimeCoverage | testHighlightQueryWithParentGrammarProvider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHighlightQueryWithParentGrammarProvider` |
| 26 | LanguageRuntimeCoverage | testFakeProviderDefaultQueryImplementations | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testFakeProviderDefaultQueryImplementations` |
| 27 | LanguageRuntimeCoverage | testGrammarProviderRegistrationAndUnregister | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testGrammarProviderRegistrationAndUnregister` |
| 28 | LanguageRuntimeCoverage | testUnregisterLanguageRemovesMappings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUnregisterLanguageRemovesMappings` |
| 29 | LanguageRuntimeCoverage | testUnregisterDoesNotStealSharedExtension | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUnregisterDoesNotStealSharedExtension` |
| 30 | LanguageRuntimeCoverage | testQueryRegistryInvalidation | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testQueryRegistryInvalidation` |

> 说明：全部 **30 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 24 / 24
- P2: 已覆盖 4 / 4
- **合计: 30 / 30**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（24 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 30 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitEditorLanguageRuntime
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
