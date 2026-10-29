# TestPlan — PluginProjectRAG

## 包概述

PluginProjectRAG 的实现包，包含 14 个主要类型；当前测试覆盖 74 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 74

核心组件（源码目录）:
- `Hooks/`
- `Navigation/`
- `Observers/`
- `Providers/`
- `Support/`
- `Tools/`
- `Core/`
- `Models/`
- `Observers/`
- `Services/`
- `Utils/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ProjectRAGPlugin`
- `ProjectRAGRuntime`
- `ProjectRAGLLMContextHook`
- `ProjectRAGProjectLifecycleHook`
- `CodeNavigationCoordinator`
- `ProjectRAGProjectObserver`
- `ProjectRAGProvider`
- `ProjectRAGSearchMemory`
- `RAGCodeSearchTool`
- `RAGConfiguration`
- `RAGIntentAnalyzer`
- `RAGLanguagePreference`
- `RAGLineRange`
- `RAGError`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（11 条）：由 `retainsStableIdentifiers`、`registersProvider`、`injectsContextOnce` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RAGIndexScheduling**（4 条）：由 `selectsMissingIndexBeforeStaleIndex`、`neverSelectsCurrentProject`、`failedProjectUsesExponentialBackoff` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RAGPureLogic**（59 条）：由 `chunkEmptyInputReturnsEmpty`、`chunkSingleBlockProducesOneChunk`、`chunkProducesOverlapAcrossBlocks` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | keeps the legacy plugin and tool identifiers | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `retainsStableIdentifiers` |
| 2 | 综合 | registers the RAG capability in KernelCore | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersProvider` |
| 3 | 综合 | injects code context once for one user message | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `injectsContextOnce` |
| 4 | 综合 | does not query RAG for casual conversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsCasualConversation` |
| 5 | 综合 | does not wait for RAG while the project is indexing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsIndexingProject` |
| 6 | 综合 | includes line evidence in tool output | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `includesLineEvidence` |
| 7 | 综合 | suppresses an immediate duplicate after automatic injection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suppressesImmediateDuplicate` |
| 8 | 综合 | does not enqueue semantic search while indexing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsSemanticSearchDuringIndexing` |
| 9 | 综合 | indexes a missing project before searching | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `indexesMissingProjectBeforeSearching` |
| 10 | 综合 | merges semantic and exact file evidence | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mergesSemanticAndExactFileEvidence` |
| 11 | 综合 | merges explicit file path evidence | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mergesExplicitFilePathEvidence` |
| 12 | RAGIndexScheduling | selectsMissingIndexBeforeStaleIndex | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectsMissingIndexBeforeStaleIndex` |
| 13 | RAGIndexScheduling | neverSelectsCurrentProject | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `neverSelectsCurrentProject` |
| 14 | RAGIndexScheduling | failedProjectUsesExponentialBackoff | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedProjectUsesExponentialBackoff` |
| 15 | RAGIndexScheduling | selectorCanRepresentAProjectThatStillNeedsIndexing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectorCanRepresentAProjectThatStillNeedsIndexing` |
| 16 | RAGPureLogic | chunkEmptyInputReturnsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `chunkEmptyInputReturnsEmpty` |
| 17 | RAGPureLogic | chunkSingleBlockProducesOneChunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chunkSingleBlockProducesOneChunk` |
| 18 | RAGPureLogic | chunkProducesOverlapAcrossBlocks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chunkProducesOverlapAcrossBlocks` |
| 19 | RAGPureLogic | chunkSkipsWhitespaceOnlyBlocks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chunkSkipsWhitespaceOnlyBlocks` |
| 20 | RAGPureLogic | chunkSplitsOversizedBlockByCharWindow | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chunkSplitsOversizedBlockByCharWindow` |
| 21 | RAGPureLogic | chunkAssignsSequentialIndices | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chunkAssignsSequentialIndices` |
| 22 | RAGPureLogic | cosineSimilarityIdenticalVectors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cosineSimilarityIdenticalVectors` |
| 23 | RAGPureLogic | cosineSimilarityOrthogonalVectors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cosineSimilarityOrthogonalVectors` |
| 24 | RAGPureLogic | cosineSimilarityOppositeVectors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cosineSimilarityOppositeVectors` |
| 25 | RAGPureLogic | cosineSimilarityMismatchedLengths | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cosineSimilarityMismatchedLengths` |
| 26 | RAGPureLogic | cosineSimilarityEmptyVectors | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cosineSimilarityEmptyVectors` |
| 27 | RAGPureLogic | cosineSimilarityZeroMagnitude | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cosineSimilarityZeroMagnitude` |
| 28 | RAGPureLogic | cosineSimilarityKnownValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cosineSimilarityKnownValue` |
| 29 | RAGPureLogic | tokenizeSplitsAsciiWords | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenizeSplitsAsciiWords` |
| 30 | RAGPureLogic | tokenizeSplitsCjkIntoScalars | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenizeSplitsCjkIntoScalars` |
| 31 | RAGPureLogic | tokenizeHandlesPunctuation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenizeHandlesPunctuation` |
| 32 | RAGPureLogic | tokenizeEmptyString | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `tokenizeEmptyString` |
| 33 | RAGPureLogic | lexicalBoostFullHit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lexicalBoostFullHit` |
| 34 | RAGPureLogic | lexicalBoostPartialHit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lexicalBoostPartialHit` |
| 35 | RAGPureLogic | lexicalBoostNoHit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lexicalBoostNoHit` |
| 36 | RAGPureLogic | lexicalBoostEmptyQuery | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `lexicalBoostEmptyQuery` |
| 37 | RAGPureLogic | sourcePathBoostScoresHits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sourcePathBoostScoresHits` |
| 38 | RAGPureLogic | sourcePathBoostEmptyTerms | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sourcePathBoostEmptyTerms` |
| 39 | RAGPureLogic | sourcePathBoostDoesNotMatchPartialPathToken | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sourcePathBoostDoesNotMatchPartialPathToken` |
| 40 | RAGPureLogic | normalizeProjectPathStripsTrailingSlash | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeProjectPathStripsTrailingSlash` |
| 41 | RAGPureLogic | normalizeProjectPathEmptyReturnsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeProjectPathEmptyReturnsEmpty` |
| 42 | RAGPureLogic | normalizeProjectPathResolvesRelative | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeProjectPathResolvesRelative` |
| 43 | RAGPureLogic | displayPathStripsProjectPrefix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayPathStripsProjectPrefix` |
| 44 | RAGPureLogic | displayPathReturnsLastComponentWhenEqualsProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayPathReturnsLastComponentWhenEqualsProject` |
| 45 | RAGPureLogic | displayPathWithoutProjectReturnsNormalizedPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayPathWithoutProjectReturnsNormalizedPath` |
| 46 | RAGPureLogic | displayPathReturnsFullPathWhenOutsideProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayPathReturnsFullPathWhenOutsideProject` |
| 47 | RAGPureLogic | shouldUseRAGEmptyMessageReturnsFalse | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `shouldUseRAGEmptyMessageReturnsFalse` |
| 48 | RAGPureLogic | shouldUseRAGChineseTrigger | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldUseRAGChineseTrigger` |
| 49 | RAGPureLogic | shouldUseRAGEnglishTrigger | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldUseRAGEnglishTrigger` |
| 50 | RAGPureLogic | shouldUseRAGFilePathReference | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldUseRAGFilePathReference` |
| 51 | RAGPureLogic | shouldUseRAGCodeMarker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldUseRAGCodeMarker` |
| 52 | RAGPureLogic | shouldUseRAGQuestionWithCodeWord | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldUseRAGQuestionWithCodeWord` |
| 53 | RAGPureLogic | shouldNotUseRAGForCasualQuestion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldNotUseRAGForCasualQuestion` |
| 54 | RAGPureLogic | shouldNotUseRAGForEnglishSubstring | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldNotUseRAGForEnglishSubstring` |
| 55 | RAGPureLogic | shouldUseRAGRejectsPlainStatement | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `shouldUseRAGRejectsPlainStatement` |
| 56 | RAGPureLogic | commonCJKIsDetected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commonCJKIsDetected` |
| 57 | RAGPureLogic | asciiIsNotCJK | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `asciiIsNotCJK` |
| 58 | RAGPureLogic | extensionAFromCJKIsDetected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extensionAFromCJKIsDetected` |
| 59 | RAGPureLogic | shouldSkipKnownBuildAndVcsDirs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldSkipKnownBuildAndVcsDirs` |
| 60 | RAGPureLogic | shouldSkipTempAndSourcePackages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldSkipTempAndSourcePackages` |
| 61 | RAGPureLogic | shouldSkipDerivedDataVariantsByPrefix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldSkipDerivedDataVariantsByPrefix` |
| 62 | RAGPureLogic | grepExcludeDirPatternsCoverExactNamesAndPrefixGlobs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `grepExcludeDirPatternsCoverExactNamesAndPrefixGlobs` |
| 63 | RAGPureLogic | discoverFilesCachedReturnsSameResultsAsUncached | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `discoverFilesCachedReturnsSameResultsAsUncached` |
| 64 | RAGPureLogic | findsMatchingSourceWithoutAnIndex | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findsMatchingSourceWithoutAnIndex` |
| 65 | RAGPureLogic | respectsSearchFileFilters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `respectsSearchFileFilters` |
| 66 | RAGPureLogic | includesContextAroundRipgrepMatch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `includesContextAroundRipgrepMatch` |
| 67 | RAGPureLogic | returnsNoResultsForMissingProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNoResultsForMissingProject` |
| 68 | RAGPureLogic | findsExplicitFilePathWithoutReadingContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findsExplicitFilePathWithoutReadingContent` |
| 69 | RAGPureLogic | extractsExplicitPathFromNaturalLanguage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractsExplicitPathFromNaturalLanguage` |
| 70 | RAGPureLogic | findsFilenameWithFastPathEnumeration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findsFilenameWithFastPathEnumeration` |
| 71 | RAGPureLogic | doesNotScanPathsForOrdinaryQueries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotScanPathsForOrdinaryQueries` |
| 72 | RAGPureLogic | persistsChunkLineRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistsChunkLineRange` |
| 73 | RAGPureLogic | removesOnlyIdenticalEvidence | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removesOnlyIdenticalEvidence` |
| 74 | RAGPureLogic | appliesResultLimitAfterDeduplication | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appliesResultLimitAfterDeduplication` |
| 75 | AppleNativeEmbedding | 并发 embed 不崩溃且维度一致 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `concurrentEmbedDoesNotCrash` |
| 76 | AppleNativeEmbedding | 并发 embed 结果与串行一致（向量稳定性） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `concurrentEmbedMatchesSerial` |
| 77 | AppleNativeEmbedding | 空文本返回零向量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyTextReturnsZeroVector` |
| 78 | AppleNativeEmbedding | embedBatch 结果数量与输入一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `embedBatchPreservesCount` |
| 79 | NLEmbeddingModelPool | 借出的泳道互不相同 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `borrowedLanesAreDistinct` |
| 80 | NLEmbeddingModelPool | 容量至少为 1 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `capacityIsAtLeastOne` |
| 81 | NLEmbeddingModelPool | 归还后可再次借出 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `releasedLaneCanBeBorrowedAgain` |
| 82 | NLEmbeddingModelPool | 池耗尽时借出会阻塞，归还后解除 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `borrowBlocksWhenExhausted` |
| 83 | NLEmbeddingModelPool | 同一泳道重复查询返回同一模型实例（缓存生效） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `laneCachesModelInstances` |
| 84 | NLEmbeddingModelPool | 没有模型的语言返回 nil 且被记录为缺失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `laneRecordsMissingModels` |
| 85 | NativeEmbeddingCandidates | 检测语言排在首位 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectedLanguageComesFirst` |
| 86 | NativeEmbeddingCandidates | 不支持的检测语言被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unsupportedDetectedLanguageIgnored` |
| 87 | NativeEmbeddingCandidates | 候选无重复 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `candidatesAreUnique` |
| 88 | WordLevelFallback | 整段文本的词级平均可用（不再返回 nil） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `averagedWordVectorWorksForLongText` |
| 89 | WordLevelFallback | 空文本的词级平均返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `averagedWordVectorReturnsNilForEmptyText` |
| 90 | WordLevelFallback | 词级平均对不同文本产生不同向量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `averagedWordVectorDistinguishesTexts` |
| 91 | EmbeddingThreshold | 长文本的 embed 显著快于句子级整段 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `longTextUsesWordLevelAveraging` |
| 92 | EmbeddingThreshold | 短文本与长文本都能产出有效向量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bothStrategiesProduceValidVectors` |
| 93 | EmbeddingThreshold | 阈值常量合理 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `thresholdIsReasonable` |

> 说明：全部 **74 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 76 / 76
- P2: 已覆盖 11 / 11
- **合计: 93 / 93**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（64 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 74 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginProjectRAG
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
