# TestPlan — PluginProjectRAG

## 包概述

PluginProjectRAG 的实现包，包含 14 个主要类型；当前测试覆盖 132 条用例。

平台: macOS 14+, iOS 17+
测试文件: 13 个，用例总数: 132

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

- **综合**（12 条）：由 `retainsStableIdentifiers`、`registersProvider`、`injectsContextOnce` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProjectRAGPlugin 启动调度**（1 条）：由 `startsIdleSchedulerWithoutCurrentProject` 锁定；启动时没有当前项目也必须启动 idle 调度，否则整轮会话的后台索引都会被跳过。
- **RAGServiceEnsureOutcome**（2 条）：由 `ensureIndexedReportsDistinctOutcomes`、`onlyIndexedAndFreshConfirmProgress` 锁定。`ensureIndexed` 必须区分 `indexed` / `fresh` / `throttled` / `paused`；只有前两者算调度进展，节流或暂停跳过不得清除失败退避，也必须等待下一个轮询间隔，否则失败索引后 scheduler 会把节流跳过记成成功并空转（**回归 #1116**）。
- **RAGServiceCancellation**（2 条）：由 `staleTokenCannotRestartBackgroundIndexing`、`foregroundIndexingIgnoresBackgroundCancellation` 锁定。后台索引令牌必须在派发前捕获；`cancelBackgroundIndexing()` 后同一令牌永久失效，迟到切片不得再打开后台索引或写入索引状态；前台索引不受后台令牌影响（**回归 #1117**）。
- **RAGIndexScheduling**（4 条）：由 `selectsMissingIndexBeforeStaleIndex`、`neverSelectsCurrentProject`、`failedProjectUsesExponentialBackoff` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RAGPureLogic**（63 条）：由 `chunkEmptyInputReturnsEmpty`、`chunkSingleBlockProducesOneChunk`、`chunkProducesOverlapAcrossBlocks` 等用例锁定；改动该模块时优先跑对应测试文件。CRLF（`\r\n`）在 Swift 中是单个 Character，必须整体算一个换行，分块窗口与 `lineRange` 都按真实源码行计算（**回归 #1114**）。
- **RAGSQLiteStoreConcurrency**（1 条）：由 `concurrentWritersOnOneConnectionDoNotCollide` 用例锁定；该用例用 8 个线程同时向同一 store 写入不同项目，移除 `RAGSQLiteStore` 的连接锁后必定因「cannot start a transaction within a transaction」失败。
- **RAGServiceModelMigration**（1 条）：由 `backgroundIndexRebuildsWhenEmbeddingModelChanged` 用例锁定；该用例预置一个模型标识过期但维度相同的索引状态，再以 `background: true` 触发索引，缺少后台迁移能力时会抛「后台索引暂不执行 embedding 模型迁移」。
- **RAGFileScannerFailure**（3 条）：由 `missingRootThrows`、`regularFileRootThrows`、`emptyDirectoryReturnsNoFiles` 用例锁定；扫描接口必须把「根目录不可用」与「项目确实为空」区分开，前者抛 `RAGError.projectRootUnavailable`，后者才返回空数组。
- **RAGIndexerScannerFailure**（2 条）：由 `incrementalIndexKeepsRecordsWhenRootDisappears`、`rebuildKeepsRecordsWhenRootDisappears` 用例锁定；项目根目录消失后索引必须中止，已索引文件数与索引状态保持不变，不得按「文件已删除」清空记录。
- **RAGIndexingRegistry**（3 条）：由 `overlappingScopesStayIndexingUntilLastFinish`、`projectScopesAreIndependent`、`unmatchedFinishDoesNotUnderflow` 锁定。同一项目的索引作用域可以重叠（`ensureIndexed` 在 await 处让出 actor），必须按项目引用计数：任一作用域先结束不得清除其他仍在运行的索引标记；不同项目互不影响；多余的 `finish` 不得留下负计数（**回归 #1110**）。
- **RAGCacheKey**（5 条）：由 `collidingQueryAndPathProduceDifferentKeys`、`cacheMissesAcrossCollidingTriples`、`identicalTriplesShareCacheEntry`、`topKParticipatesInTheKey`、`replacedProjectPathStillMisses` 锁定。query 与项目路径都允许出现 `|` 等字符，缓存键必须按字段长度编码而不是直接拼接分隔符，否则不同三元组会共用缓存并返回其他查询/项目的结果（**回归 #1112**）。
- **RAGLexicalIgnore**（2 条）：由 `ripgrepArgumentsDisableIgnoreRules`、`lexicalSearchFindsSourceInGitignoredDirectory` 锁定。索引扫描和路径搜索都不读取 `.gitignore`，词法搜索的 ripgrep 参数必须带 `--no-ignore`，否则被忽略目录中的源码在有其他匹配时会被静默漏掉（**回归 #1113**）。
- **RAGSQLiteCandidateDedup**（3 条）：由 `mergeKeepsChunksThatShareContentPrefix`、`partialMatchDoesNotEvictFullMatch`、`fallbackOverlapIsDeduplicated` 锁定。词法与回退候选合并必须按数据库 chunk id 去重；不能用「路径 + 内容前 80 字符」，否则同前缀的不同 chunk 会互相覆盖，完整命中的旧 chunk 会在评分前被较新的部分匹配挤掉（**回归 #1115**）。
- **RAGSQLiteBlobBinding**（2 条）：由 `sqliteCopiesBlobBeforeBindReturns`、`storedEmbeddingSurvivesSourceBufferRelease` 锁定。`withUnsafeBytes` 只保证 buffer 在闭包内有效，`sqlite3_step` 在闭包外执行，因此 blob 必须用 `SQLITE_TRANSIENT` 绑定，让 SQLite 在 bind 返回前复制；bind 后覆写源缓冲区仍应能读回原值（**回归 #1111**）。

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
| 94 | ProjectRAGPlugin | search_code 未传 project_path 时使用会话绑定项目 | 会话绑定一个不存在的项目路径 | 调用 `executeResult(context:arguments:)` | 报错路径为会话项目而非当前项目 | P1 | ✅ 已覆盖 | `usesConversationProject` |
| 95 | ProjectRAGPlugin | search_code 显式 project_path 优先于会话绑定项目 | 会话绑定项目 A，显式传 B | 调用 `executeResult(context:arguments:)` | 报错路径为 B，不含 A | P1 | ✅ 已覆盖 | `explicitPathBeatsConversationProject` |
| 96 | RAGSQLiteStoreConcurrency | 并发索引不同项目不会因同一连接的嵌套事务互相失败 | 单一 `RAGSQLiteStore` 连接 | 8 个线程同时释放并各写入一个不同项目的 200 个 chunk | 全部写入成功，每个项目都有完整的文件状态与 chunk | P0 | ✅ 已覆盖 | `concurrentWritersOnOneConnectionDoNotCollide` |
| 97 | RAGServiceModelMigration | 模型不匹配时后台索引仍完成全量重建 | 索引状态记录旧 embedding 模型，维度与当前一致 | 以 `background: true` 调用 `ensureIndexed` | 重建完成，索引状态与 chunk 数量更新为新模型 | P1 | ✅ 已覆盖 | `backgroundIndexRebuildsWhenEmbeddingModelChanged` |
| 98 | ProjectRAGPlugin 启动调度 | 启动时没有当前项目也会启动 idle 调度 | kernel 注册了项目与 idle 能力，但当前项目为 nil | 调用 `onBoot` 并等待后台任务 | `scheduler` 非 nil；关闭后恢复 nil | P1 | ✅ 已覆盖 | `startsIdleSchedulerWithoutCurrentProject` |
| 99 | ProjectRAGProvider 观察者生命周期 | 释放 handle 后不再收到事件 | Provider 已注册一个观察者 | 广播事件、释放 handle 后再广播 | 释放前后事件次数不变 | P1 | ✅ 已覆盖 | `releasedHandleStopsReceivingEvents` |
| 100 | ProjectRAGProvider 观察者生命周期 | 释放 handle 后回调捕获的值可以释放 | 回调强引用一个测试对象 | 释放 handle 并检查弱引用 | 弱引用变为 nil，Provider 不再强持有回调 | P1 | ✅ 已覆盖 | `releasingHandleReleasesCallbackCapture` |
| 101 | ProjectRAGProvider 观察者生命周期 | cancel 立即注销观察者 | Provider 已注册一个观察者 | 调用 `cancel` 后再广播事件 | 回调只收到注销前的事件 | P1 | ✅ 已覆盖 | `cancelRemovesObserver` |
| 102 | RAGInjectionDeduplication | 去重键只保存固定长度摘要 | — | 用含敏感正文的消息构造去重键并比较 | 摘要为 64 位十六进制且不含原文；会话 ID 或消息序号不同则为不同键 | P1 | ✅ 已覆盖 | `keyStoresOnlyDigest` |
| 103 | RAGInjectionDeduplication | 超过容量后淘汰最旧的回合 | 容量为 2 的去重窗口 | 依次记录三个不同回合 | 集合始终不超过 2 条，最旧回合被淘汰 | P1 | ✅ 已覆盖 | `evictsOldestTurnBeyondCapacity` |
| 104 | RAGInjectionDeduplication | 重复记录同一回合不会扩大窗口 | 容量为 2 的去重窗口 | 记录同一回合两次再记录另一回合 | 集合为 2 条且原回合仍被记住 | P1 | ✅ 已覆盖 | `recordingSameTurnIsIdempotent` |
| 105 | RAGFileScannerFailure | 项目根目录不存在时扫描抛错 | — | 对不存在的路径调用 `discoverFilesOrThrow` | 抛 `RAGError.projectRootUnavailable`；宽松接口仍返回空数组 | P1 | ✅ 已覆盖 | `missingRootThrows` |
| 106 | RAGFileScannerFailure | 根路径是普通文件时扫描抛错 | 根路径指向一个 .swift 文件 | 对该路径调用 `discoverFilesOrThrow` | 抛 `RAGError.projectRootUnavailable` | P1 | ✅ 已覆盖 | `regularFileRootThrows` |
| 107 | RAGFileScannerFailure | 空目录扫描返回空数组 | 创建一个无文件的临时目录 | 对该目录调用 `discoverFilesOrThrow` | 返回空数组且不抛错 | P1 | ✅ 已覆盖 | `emptyDirectoryReturnsNoFiles` |
| 108 | RAGIndexerScannerFailure | 增量索引时项目根消失保留旧记录 | 已成功索引一个含 Swift 文件的项目 | 删除项目目录后再执行增量索引 | 抛错，已索引文件数与索引状态保持不变 | P1 | ✅ 已覆盖 | `incrementalIndexKeepsRecordsWhenRootDisappears` |
| 109 | RAGIndexerScannerFailure | 全量重建时项目根消失保留旧记录 | 已成功重建一个含 Swift 文件的项目 | 删除项目目录后再执行全量重建 | 抛错，已索引文件数保持不变（扫描先于删除） | P1 | ✅ 已覆盖 | `rebuildKeepsRecordsWhenRootDisappears` |
| 110 | RAGIndexingRegistry | 重叠索引作用域在最后一个结束前保持索引状态（**回归 #1110**） | 对同一项目调用两次 `start` | 调用一次 `finish` 后再查询 | `contains` 与 `hasAnyIndexing` 仍为真；第二次 `finish` 后才清空 | P0 | ✅ 已覆盖 | `overlappingScopesStayIndexingUntilLastFinish` |
| 111 | RAGIndexingRegistry | 不同项目的索引状态互不影响 | 两个项目各 `start` 一次 | 结束第一个项目 | 第一个项目不再 indexing，第二个仍 indexing | P1 | ✅ 已覆盖 | `projectScopesAreIndependent` |
| 112 | RAGIndexingRegistry | 多余的 finish 不会留下负计数 | 未调用 `start` | 直接调用 `finish` 后再 `start`/`finish` | 多余 `finish` 后为空；正常配对后仍能正确清空 | P2 | ✅ 已覆盖 | `unmatchedFinishDoesNotUnderflow` |
| 113 | RAGSQLiteBlobBinding | SQLite 在 bind 返回前复制 blob（**回归 #1111**） | 创建内存表并准备插入语句 | 用原始指针绑定 blob，bind 返回后覆写源缓冲区再 step/读回 | 读回值与原值一致，证明 SQLite 已复制 | P0 | ✅ 已覆盖 | `sqliteCopiesBlobBeforeBindReturns` |
| 114 | RAGSQLiteBlobBinding | 源缓冲区释放后仍能读回完整向量（**回归 #1111**） | 临时数据库与已知 embedding | `replaceFileChunks` 后制造内存复用并 `loadChunks` | 读回的 embedding 与写入值一致 | P1 | ✅ 已覆盖 | `storedEmbeddingSurvivesSourceBufferRelease` |
| 115 | RAGCacheKey | 含分隔符的 query/项目路径不产生相同缓存键（**回归 #1112**） | topK 固定为 3 | 对比 `("alpha\|/tmp/B", "/tmp/A")` 与 `("alpha", "/tmp/B\|/tmp/A")` 的 key | 两个 key 不相等 | P0 | ✅ 已覆盖 | `collidingQueryAndPathProduceDifferentKeys` |
| 116 | RAGCacheKey | 碰撞三元组之间不共享缓存条目（**回归 #1112**） | 先写入第一组结果 | 用第二组三元组构造 key 并 `get` | 返回 nil，未命中第一组结果 | P0 | ✅ 已覆盖 | `cacheMissesAcrossCollidingTriples` |
| 117 | RAGCacheKey | 相同三元组稳定命中同一条目 | 写入 query/projectPath/topK 完全相同的结果 | 用相同三元组再次构造 key 并 `get` | key 相同且读回原结果 | P1 | ✅ 已覆盖 | `identicalTriplesShareCacheEntry` |
| 118 | RAGCacheKey | topK 参与缓存键 | 其他字段相同 | 分别用 topK 3 与 4 构造 key | 两个 key 不相等 | P1 | ✅ 已覆盖 | `topKParticipatesInTheKey` |
| 119 | RAGCacheKey | 切换项目路径后不复用旧缓存 | 已向项目 A 写入结果 | 用项目 B 构造 key 并 `get` | 返回 nil | P1 | ✅ 已覆盖 | `replacedProjectPathStillMisses` |
| 120 | RAGLexicalIgnore | ripgrep 词法参数禁用 ignore 规则（**回归 #1113**） | 任意查询词与项目路径 | 构造 `RAGLexicalFileSearcher.ripgrepArguments` | 参数包含 `--no-ignore`，项目路径位于末尾 | P0 | ✅ 已覆盖 | `ripgrepArgumentsDisableIgnoreRules` |
| 121 | RAGLexicalIgnore | 词法搜索包含被忽略目录中的源码（**回归 #1113**） | 临时 git 仓库，`.gitignore` 忽略 `generated/` | `Tracked.swift` 与 `generated/Ignored.swift` 都含查询词，执行词法搜索 | 两条来源都出现在结果中，不得遗漏被忽略目录 | P0 | ✅ 已覆盖 | `lexicalSearchFindsSourceInGitignoredDirectory` |
| 122 | RAGPureLogic | CRLF 只计一次换行，内容与行号正确（**回归 #1114**） | 内容为 `"a\r\nb"` | 执行 `RAGChunker().chunk` | 内容为 `"a\nb"`，`lineRange` 为 1...2 | P0 | ✅ 已覆盖 | `chunkTreatsCRLFAsSingleLineBreak` |
| 123 | RAGPureLogic | CRLF 文件按真实源码行切窗口 | 10 行内容全部用 `\r\n` 连接 | `maxLines: 4, overlapLines: 0` 执行分块 | 窗口为 1...4、5...8、9...10 | P1 | ✅ 已覆盖 | `chunkCountsCRLFWindowsBySourceLines` |
| 124 | RAGPureLogic | CRLF 中的空行仍占真实行号 | 内容为 `"a\r\n\r\nb"` | 执行分块 | 内容为 `"a\n\nb"`，`lineRange` 为 1...3 | P1 | ✅ 已覆盖 | `chunkKeepsBlankLineInCRLF` |
| 125 | RAGPureLogic | 单独的 CR 也作为换行 | 内容为 `"a\rb"` | 执行分块 | 内容为 `"a\nb"`，`lineRange` 为 1...2 | P2 | ✅ 已覆盖 | `chunkTreatsLoneCarriageReturnAsLineBreak` |
| 126 | RAGSQLiteCandidateDedup | 前 80 字符相同的不同 chunk 不被合并丢弃（**回归 #1115**） | 同一文件两个 chunk 共享 80 字符前缀，后续内容不同 | `loadCandidateChunks` 检索 `alpha beta` | 两个 chunk 都保留 | P0 | ✅ 已覆盖 | `mergeKeepsChunksThatShareContentPrefix` |
| 127 | RAGSQLiteCandidateDedup | 较新的部分匹配不挤掉较旧的完整匹配（**回归 #1115**） | 旧 chunk 含 `alpha beta`，新 chunk 只含 `alpha`，前缀相同 | `loadCandidateChunks` 检索 `alpha beta` | 旧、新 chunk 的 id 都在候选中 | P0 | ✅ 已覆盖 | `partialMatchDoesNotEvictFullMatch` |
| 128 | RAGSQLiteCandidateDedup | 词法与回退重叠的同一 chunk 只保留一次 | 单 chunk 命中查询词 | `loadCandidateChunks` 合并词法与回退 | 结果仅一条，内容不变 | P1 | ✅ 已覆盖 | `fallbackOverlapIsDeduplicated` |
| 129 | RAGServiceEnsureOutcome | 暂停/新鲜/节流/完成索引返回不同结果（**回归 #1116**） | 当前模型且刚索引过的项目、无索引项目 | 依次在暂停、新鲜、节流与缺索引状态调用 `ensureIndexed` | 分别返回 `.paused`、`.fresh`、`.throttled`、`.indexed` | P0 | ✅ 已覆盖 | `ensureIndexedReportsDistinctOutcomes` |
| 130 | RAGServiceEnsureOutcome | 只有完成索引或索引新鲜算作进展（**回归 #1116**） | 四种结果值 | 检查 `confirmsProgress` | `indexed`/`fresh` 为 true，`throttled`/`paused` 为 false | P1 | ✅ 已覆盖 | `onlyIndexedAndFreshConfirmProgress` |
| 131 | RAGServiceCancellation | 中断前捕获的令牌无法重新打开后台索引（**回归 #1117**） | 服务已初始化，先捕获令牌再调用 `cancelBackgroundIndexing` | 用旧令牌以 `background: true` 调用 `ensureIndexed`（连续两次），再用新令牌索引 | 旧令牌抛 `CancellationError` 且没有写入索引状态；新令牌返回 `.indexed` 且 chunk 数大于 0 | P0 | ✅ 已覆盖 | `staleTokenCannotRestartBackgroundIndexing` |
| 132 | RAGServiceCancellation | 前台索引不受后台取消令牌影响 | 服务已初始化并调用过 `cancelBackgroundIndexing` | 以 `background: false` 调用 `ensureIndexed` | 返回 `.indexed`，索引状态有 chunk，前台工作不被后台令牌阻断 | P1 | ✅ 已覆盖 | `foregroundIndexingIgnoresBackgroundCancellation` |

> 说明：全部 **132 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 18 / 18
- P1: 已覆盖 101 / 101
- P2: 已覆盖 13 / 13
- **合计: 132 / 132**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（18 条）
- **P1**: 其余功能性用例（101 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（13 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 132 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
