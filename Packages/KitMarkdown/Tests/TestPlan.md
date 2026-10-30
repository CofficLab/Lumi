# TestPlan — KitMarkdown

## 包概述

KitMarkdown 是可复用的 Markdown 解析与渲染组件，采用**双 target** 结构：
`KitMarkdownCore` 为纯解析/模型层（依赖 `swift-markdown`），
`KitMarkdown` 为 UI 渲染层（含 Mermaid 渲染，依赖 `beautiful-mermaid-swift`）。

核心组件:
- **KitMarkdownCore**
  - `MarkdownBlock` - 解析产物模型（heading / paragraph / codeBlock / quote / table /
    thematicBreak / list / orderedList / listItem / taskState）
  - `MarkdownParser` - 主入口，把 Markdown 文本解析为 `[MarkdownBlock]`
  - `MarkdownTableNormalizer` - 表格补全/规整（补分隔行、合并断行、补齐短行、归一化对齐）
  - `MarkdownTableRowParser` - 表格行切分（含转义竖线处理）
- **KitMarkdown**（渲染层）
  - `HorizontalFittingSizeCache` - 横向适配尺寸缓存（按指纹 + 量化宽度分桶）
  - 代码块 / 引用块的 SwiftUI 布局视图（`HorizontalScrollView` 等）
  - Mermaid 渲染
- **KitMarkdownTesting** - 布局测试支撑（仅供测试 target 使用）

## 公开 API

### MarkdownBlock
- 各类 block 的构造与 `Equatable`：`heading` / `paragraph` / `codeBlock` / `quote` /
  `table` / `thematicBreak`
- `listItem` / `orderedItem` / `taskState`：`isCompleted` 区分任务项状态

### MarkdownParser
- `parse(_ text: String) -> [MarkdownBlock]` - 主解析入口

### MarkdownTableNormalizer
- `normalize(_ text: String) -> String` - 规整 Markdown 表格

### HorizontalFittingSizeCache
- 按 `fingerprint`（内容）+ 量化宽度（16pt 步进）分桶缓存测量结果

## 关键行为契约（实现约定，非协议要求）

- **表格规整只作用于真正的表格**：含竖线的普通段落（shell 管道 `a | b`、
  TypeScript 联合类型 `string | number`）必须保持段落形态。
  `doesNotTreatSingleParagraphWithPipesAsTable` /
  `preservesShellPipelineTextAsParagraph` /
  `preservesTypeScriptUnionTextAsParagraph` 三条共同锁定这一边界——
  误判会把代码高亮整段吃掉。
- **表格分隔行合法才当表格**：分隔行单元格数需与表头一致，否则回退为段落
  （`fallsBackToParagraphWhenTableSeparatorIsInvalid`）。
- **围栏代码块内的表格不参与规整**：``` 与 ~~~ 两种围栏、以及缩进代码块内的
  `|` 都必须原样保留（ID 中的 `preservesPipeTablesInside*FencedCodeBlocks`）。
- **未闭合的行内定界符降级为纯文本**：`**` 未配对、空定界、纯空白定界一律
  按字面输出，不吞掉用户内容（`preservesUnclosedStrongDelimiterAsPlainText` 等）。
- **原生 Markdown 已能正确解析时不得改动**：加粗、行内代码、链接三类优先用
  `swift-markdown` 原生结果，仅在中文紧邻等场景才走回退解析
  （`preservesNative*WhenItAlreadyWorks`）。回退路径是补丁，不是主路径。
- **CJK 紧邻场景需回退**：`中文**加粗**` 中 `swift-markdown` 不识别，
  故自建回退（`parsesStrongTextAfterChineseWithoutWhitespace`），
  且标点起始的定界段也需覆盖。
- **横向尺寸按 16pt 量化分桶**：流式输出时宽度抖动会造成测量风暴，
  量化后同桶复用缓存（`widthJitterWithinSameBucketStillHits`），
  但内容变化必须逐 token 失效（`streamingGrowthInvalidatesEveryToken`）。
- **流式解析必须与全量解析等价**：分段追加解析在每一步都要与一次性解析结果
  一致（`streamingAppendMatchesFullParseAtEachStep`），
  否则流式过程中会看到错乱排版。
- **多行代码块在聊天列表中不得被垂直截断**：`preferOuterScroll` + `List` 场景下，
  根因是 `HorizontalScrollView` 的 `heightAnchor` 锁死 hostingView 高度且缺少
  `sizeThatFits`；长代码行则需要 `leadingAnchor` 与最小宽度约束才能水平滚动。
- **引用块不得制造过多垂直空白**：`quoteBlockIsNotTallerThanEquivalentParagraph`
  等 12 条断言覆盖「引用块高度 ≈ 同内容段落高度」，横跨 bubble / list /
  full-message / listRow 四种容器与「引用后接段落/代码块」的组合。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 模型 | heading block 相等性 | 构造相同 heading | 比较 | `Equatable` 为 true | P1 | ✅ 已覆盖 | `headingBlockEquality` |
| 2 | 模型 | paragraph block 相等性 | 构造相同 paragraph | 比较 | 相等 | P1 | ✅ 已覆盖 | `paragraphBlockEquality` |
| 3 | 模型 | codeBlock 相等性 | 构造相同代码块 | 比较 | 相等（含语言与内容） | P1 | ✅ 已覆盖 | `codeBlockEquality` |
| 4 | 模型 | quote block 相等性 | 构造相同引用 | 比较 | 相等 | P1 | ✅ 已覆盖 | `quoteBlockEquality` |
| 5 | 模型 | table block 相等性 | 构造相同表格 | 比较 | 相等 | P1 | ✅ 已覆盖 | `tableBlockEquality` |
| 6 | 模型 | thematicBreak 相等性 | 构造相同分隔符 | 比较 | 相等 | P2 | ✅ 已覆盖 | `thematicBreakEquality` |
| 7 | 模型 | listItem 初始化 | 构造列表项 | 检查字段 | 文本与标记正确、无任务态 | P1 | ✅ 已覆盖 | `listItemInitialization` |
| 8 | 模型 | 无任务态的 listItem | 普通 `-` 项 | 检查 `taskState` | 不带任务状态 | P1 | ✅ 已覆盖 | `listItemWithoutTaskState` |
| 9 | 模型 | listItem 相等性 | 构造相同列表项 | 比较 | 相等 | P1 | ✅ 已覆盖 | `listItemEquality` |
| 10 | 模型 | orderedItem 初始化 | 构造有序项 | 检查序号 | 序号正确 | P1 | ✅ 已覆盖 | `orderedItemInitialization` |
| 11 | 模型 | orderedItem 相等性 | 构造相同有序项 | 比较 | 相等 | P1 | ✅ 已覆盖 | `orderedItemEquality` |
| 12 | 模型 | taskState 相等性 | 构造相同任务态 | 比较 | 相等 | P1 | ✅ 已覆盖 | `taskStateEquality` |
| 13 | 模型 | 已完成任务态可判定 | 勾选任务 | 读 `isCompleted` | 为 true | P1 | ✅ 已覆盖 | `taskStateIsCompleted` |
| 14 | 解析 | 空文档解析为空 | 输入空串 | `parse` | 返回空数组 | P0 | ✅ 已覆盖 | `parsesEmptyDocument` |
| 15 | 解析 | 纯空白文档解析为空 | 输入纯空白 | `parse` | 返回空数组 | P0 | ✅ 已覆盖 | `parsesWhitespaceOnly` |
| 16 | 解析 | 多级标题正确分层 | 输入 h1–h6 | `parse` | 层级与顺序正确 | P0 | ✅ 已覆盖 | `parsesMultipleHeadingLevels` |
| 17 | 解析 | 无语言代码块 | 裸 ``` 块 | `parse` | 识别为 codeBlock，语言为空 | P1 | ✅ 已覆盖 | `parsesCodeBlockWithNoLanguage` |
| 18 | 解析 | 多行代码块不被截断 | 输入多行代码块 | `parse` | 行数完整保留 | P0 | ✅ 已覆盖 | `parsesMultilineCodeBlock` |
| 19 | 解析 | 嵌套引用 | 多层 `>` | `parse` | 层级正确 | P1 | ✅ 已覆盖 | `parsesNestedQuotes` |
| 20 | 解析 | 混合列表标记 | `-` / `*` / `+` 混用 | `parse` | 统一识别为列表 | P1 | ✅ 已覆盖 | `parsesMixedListMarkers` |
| 21 | 解析 | 有序列表自定义起始 | `3.` 起始 | `parse` | 起始序号为 3 | P1 | ✅ 已覆盖 | `parsesOrderedListWithCustomStart` |
| 22 | 解析 | 任务列表混合状态 | `[ ]` 与 `[x]` 混用 | `parse` | 逐项状态正确 | P1 | ✅ 已覆盖 | `parsesTaskListWithMixedCases` |
| 23 | 解析 | 表格对齐标记 | `:---:` 等 | `parse` | 对齐信息正确 | P1 | ✅ 已覆盖 | `parsesTableWithAlignment` |
| 24 | 解析 | 表格多余列 | 表头与分隔行不一致 | `parse` | 按实际列数处理 | P1 | ✅ 已覆盖 | `parsesTableWithExtraColumns` |
| 25 | 解析 | 多个分隔符 | 多个 `---` | `parse` | 每个都成为 thematicBreak | P1 | ✅ 已覆盖 | `parsesMultipleThematicBreaks` |
| 26 | 解析 | Unicode 内容保留 | 中英混排 | `parse` | 内容无损 | P1 | ✅ 已覆盖 | `handlesUnicodeInContent` |
| 27 | 解析 | 复杂文档整体解析 | 标题+段落+列表+表格+代码 | `parse` | 各 block 顺序与内容均正确 | P0 | ✅ 已覆盖 | `parsesComplexDocument` |
| 28 | 解析 | Mermaid 代码块识别 | mermaid 语言标记及变体 | `parse` | 判定为 Mermaid 块 | P1 | ✅ 已覆盖 | `isMermaidCodeBlockWithVariations` |
| 29 | 解析 | 标题/段落/分隔符组合 | 三种 block 混排 | `parse` | 各 block 正确切分 | P1 | ✅ 已覆盖 | `parsesHeadingsParagraphsAndThematicBreaks` |
| 30 | 解析 | 任务列表与有序列表 | 两类列表并存 | `parse` | 分别正确识别 | P1 | ✅ 已覆盖 | `parsesTaskListsAndOrderedLists` |
| 31 | 解析 | 代码块/引用/语言标记 | 混排 | `parse` | 三类均正确 | P1 | ✅ 已覆盖 | `parsesCodeBlocksQuotesAndMermaidLanguage` |
| 32 | 解析 | 管道表格且短行补齐 | 含短行的表格 | `parse` | 短行被补齐为等宽 | P0 | ✅ 已覆盖 | `parsesPipeTablesAndPadsShortRows` |
| 33 | 解析 | 列表项保留行内 Markdown | 含 `**` 的列表项 | `parse` | 行内标记不被吞 | P1 | ✅ 已覆盖 | `preservesInlineMarkdownInListItems` |
| 34 | 解析 | 引用内保留行内 Markdown | 含行内标记的引用 | `parse` | 行内标记不被吞 | P1 | ✅ 已覆盖 | `preservesInlineMarkdownInQuotes` |
| 35 | 解析 | 中文文档不丢行内 Markdown | 中英混排含行内标记 | `parse` | 行内标记完整保留 | P0 | ✅ 已覆盖 | `parsesMixedChineseDocumentWithoutLosingInlineMarkdown` |
| 36 | 表格 | 非法分隔行回退为段落 | 分隔行列数不符 | 解析 | 整段按段落处理 | P0 | ✅ 已覆盖 | `fallsBackToParagraphWhenTableSeparatorIsInvalid` |
| 37 | 表格 | 规范表格保持不变 | 合法表格 | 规整 | 输出等于输入 | P1 | ✅ 已覆盖 | `leavesWellFormedTableUnchanged` |
| 38 | 表格 | 补全缺失的分隔行 | 缺分隔行 | 规整 | 自动插入分隔行 | P0 | ✅ 已覆盖 | `insertsMissingSeparatorLine` |
| 39 | 表格 | 单段含竖线不当表格 | `a \| b` 单段 | 规整 | 保持段落 | P0 | ✅ 已覆盖 | `doesNotTreatSingleParagraphWithPipesAsTable` |
| 40 | 表格 | 竖线文本段落保留 | 含竖线的段落 | 规整 | 原样保留 | P1 | ✅ 已覆盖 | `preservesParagraphAfterPipeText` |
| 41 | 表格 | shell 管道不被当表格 | `a \| b` 命令行 | 规整 | 保持段落（代码高亮不被破坏） | P0 | ✅ 已覆盖 | `preservesShellPipelineTextAsParagraph` |
| 42 | 表格 | TS 联合类型不被当表格 | `string \| number` | 规整 | 保持段落 | P0 | ✅ 已覆盖 | `preservesTypeScriptUnionTextAsParagraph` |
| 43 | 表格 | 连续竖线文本行保持段落 | 多行含竖线文本 | 规整 | 全部按段落保留 | P1 | ✅ 已覆盖 | `preservesConsecutivePipeTextLinesAsParagraph` |
| 44 | 表格 | 断行与续行合并 | 表格行跨物理行 | 规整 | 合并为一行 | P1 | ✅ 已覆盖 | `mergesBrokenRowWithContinuation` |
| 45 | 表格 | 短行补齐为等宽 | 存在短行 | 规整 | 各行列数一致 | P1 | ✅ 已覆盖 | `padsShortRows` |
| 46 | 表格 | 单元格内转义竖线保留 | `a \| b` 单元格 | 规整 | 还原为字面竖线且不拆列 | P0 | ✅ 已覆盖 | `preservesEscapedPipesInsideCells` |
| 47 | 表格 | 对齐标记归一化 | `:---:` / `---:` | 规整 | 统一为标准写法 | P1 | ✅ 已覆盖 | `normalizesAlignSpecifiers` |
| 48 | 表格 | 非法分隔行单元格当数据 | 分隔行含非法单元格 | 规整 | 该行按数据行处理而非丢弃 | P1 | ✅ 已覆盖 | `preservesInvalidSeparatorCellsAsData` |
| 49 | 表格 | 非表格内容保留 | 混排文档 | 规整 | 非表格部分不变 | P0 | ✅ 已覆盖 | `preservesNonTableContent` |
| 50 | 表格 | 紧邻表格的竖线段落保留 | 表格后紧跟 `\|` 段落 | 规整 | 段落不被并入表格 | P0 | ✅ 已覆盖 | `preservesPipeParagraphImmediatelyAfterTable` |
| 51 | 表格 | 空内容安全处理 | 空串 | 规整 | 不崩溃 | P1 | ✅ 已覆盖 | `handlesEmptyContent` |
| 52 | 表格 | 非表格 Markdown 保留 | 纯 Markdown | 规整 | 输出等于输入 | P1 | ✅ 已覆盖 | `preservesNonTableMarkdown` |
| 53 | 表格 | 围栏代码块内的表格不规整 | ``` 块内含表格 | 规整 | 围栏内容原样保留 | P0 | ✅ 已覆盖 | `preservesPipeTablesInsideFencedCodeBlocks` |
| 54 | 表格 | 波浪号围栏内的表格不规整 | ~~~ 块内含表格 | 规整 | 原样保留 | P0 | ✅ 已覆盖 | `preservesPipeTablesInsideTildeFencedCodeBlocks` |
| 55 | 表格 | 缩进代码块内的表格不规整 | 缩进代码块含表格 | 规整 | 原样保留 | P1 | ✅ 已覆盖 | `preservesPipeTablesInsideIndentedCodeBlocks` |
| 56 | 代码块 | 多行代码块解析完整 | 多行 swift 代码 | `parse` | 内容与行数完整 | P0 | ✅ 已覆盖 | `parsesMultiLineCodeBlockWithoutTruncation` |
| 57 | 代码块 | 单行代码块解析 | ` ```python ` 单行 | `parse` | 语言与内容正确 | P1 | ✅ 已覆盖 | `parsesSingleLineCodeBlock` |
| 58 | 代码块 | 代码块保留空行 | 含空行代码 | `parse` | 空行不被剔除 | P1 | ✅ 已覆盖 | `parsesCodeBlockPreservingEmptyLines` |
| 59 | 布局 | 横向滚动文档视图随内容增高 | 长多行代码 | 度量 | documentView 高度随行数增长 | P0 | ✅ 已覆盖 | `horizontalScrollViewDocumentViewGrowsWithContent` |
| 60 | 布局 | 文档视图不被 clipView 高度锁死 | 多行代码 | 度量 | 不受 clipView 约束限制（截断回归） | P0 | ✅ 已覆盖 | `horizontalScrollViewNotConstrainedToClipViewHeight` |
| 61 | 布局 | 长行文档宽度超出容器 | 超长单行 | 度量 | 宽度超出后可水平滚动 | P0 | ✅ 已覆盖 | `horizontalScrollViewDocumentWidthExceedsContainerForLongContent` |
| 62 | 布局 | 文档视图左对齐 | 短内容 | 度量 | 靠 leadingAnchor 对齐 | P1 | ✅ 已覆盖 | `horizontalScrollViewDocumentViewAnchoredToLeading` |
| 63 | 布局 | 多行内容高度合理 | 多行代码 | 度量 | 高度符合行数预期 | P1 | ✅ 已覆盖 | `horizontalScrollViewMultilineContentHeightIsReasonable` |
| 64 | 布局 | 列表内代码块不塌陷为 0 高 | 列表项含代码块 | 度量 | 高度非 0 | P0 | ✅ 已覆盖 | `codeBlockInListRendersWithoutZeroHeight` |
| 65 | 布局 | 列表内多行代码块用横向滚动高度 | 列表项含多行代码 | 度量 | 高度取 documentView 而非容器 | P0 | ✅ 已覆盖 | `multiLineCodeBlockInListUsesHorizontalScrollDocumentHeight` |
| 66 | 布局 | 代码块后接段落在列表中不留过多空白 | 列表项含「代码+段落」 | 度量 | 底部高度被保留、无冗余空白 | P1 | ✅ 已覆盖 | `codeBlockFollowedByParagraphInListNoExcessiveWhitespace` |
| 67 | 尺寸缓存 | 宽度量化到 16pt 步进 | 任意宽度 | 分桶 | 落入 16pt 倍数桶 | P1 | ✅ 已覆盖 | `bucketedWidthQuantizesTo16PointSteps` |
| 68 | 尺寸缓存 | 同指纹同宽度命中缓存 | 指纹与宽度不变 | 再次请求 | 命中，不重新测量 | P0 | ✅ 已覆盖 | `sameFingerprintAndWidthHitsCache` |
| 69 | 尺寸缓存 | 桶内宽度抖动仍命中 | 宽度在同桶内抖动 | 再次请求 | 命中（量化生效） | P0 | ✅ 已覆盖 | `widthJitterWithinSameBucketStillHits` |
| 70 | 尺寸缓存 | 指纹变化未命中 | 内容变化 | 再次请求 | 未命中，重新测量 | P0 | ✅ 已覆盖 | `changedFingerprintMisses` |
| 71 | 尺寸缓存 | 跨桶宽度未命中 | 宽度跨越桶边界 | 再次请求 | 未命中 | P1 | ✅ 已覆盖 | `crossBucketWidthMisses` |
| 72 | 尺寸缓存 | 重复写入覆盖旧测量 | 连续写入 | 再写一次 | 只保留最新测量 | P1 | ✅ 已覆盖 | `storeOverwritesPreviousMeasurement` |
| 73 | 尺寸缓存 | 内容不变只测量一次 | 反复更新 | 多次请求 | 仅首次真正测量 | P0 | ✅ 已覆盖 | `repeatedUpdatesWithUnchangedContentMeasureOnce` |
| 74 | 尺寸缓存 | 流式增长逐 token 失效 | 流式追加 | 每个 token 后请求 | 每次都重新测量（不误命中） | P0 | ✅ 已覆盖 | `streamingGrowthInvalidatesEveryToken` |
| 75 | 尺寸缓存 | 共享 store 跨 Coordinator 重建存活 | 重建 Coordinator | 再次请求 | 仍命中共享缓存 | P1 | ✅ 已覆盖 | `sharedStoreSurvivesCoordinatorRebuild` |
| 76 | 尺寸缓存 | 共享 store 容量有界 | 大量不同指纹 | 写入 | 超限后淘汰旧条目 | P2 | ✅ 已覆盖 | `sharedStoreEvictsBounded` |
| 77 | 异步布局 | 渲染器以同步解析结果初始化 | 已解析 blocks | 构造渲染器 | blocks 立即可用 | P1 | ✅ 已覆盖 | `markdownRendererInitializesWithSynchronouslyParsedBlocks` |
| 78 | 异步布局 | 聊天滚动中高度与独立渲染一致 | 相同内容两处渲染 | 比较高度 | 两者相等 | P0 | ✅ 已覆盖 | `markdownInChatScrollMatchesStandaloneHeight` |
| 79 | 异步布局 | 挂载后短时间内高度稳定 | 挂载后立即测量 | 多次测量 | 高度收敛不抖动 | P0 | ✅ 已覆盖 | `markdownInChatScrollHeightIsStableShortlyAfterMount` |
| 80 | 聊天列表 | 聊天滚动中多行代码块高度与独立渲染一致 | 多行代码 | 比较高度 | 两者相等 | P0 | ✅ 已覆盖 | `multiLineCodeBlockInChatScrollMatchesStandaloneHeight` |
| 81 | 聊天列表 | 横向滚动内文档视图增长 | 多行代码 | 度量 | 高度正确增长 | P1 | ✅ 已覆盖 | `multiLineCodeBlockDocumentViewGrowsInsideHorizontalScrollView` |
| 82 | 聊天列表 | preferOuterScroll 下代码块不被截断 | 该滚动模式 | 度量 | 内容完整可见 | P0 | ✅ 已覆盖 | `preferOuterScrollStandaloneCodeBlockIsNotTruncated` |
| 83 | 聊天列表 | 代码块后接段落保留底部内容高度 | 「代码+段落」 | 度量 | 底部内容高度完整 | P1 | ✅ 已覆盖 | `codeBlockFollowedByParagraphRetainsBottomContentHeight` |
| 84 | 行内 | 中文紧接加粗可识别 | `中文**加粗**` | 解析 | 识别为加粗 | P0 | ✅ 已覆盖 | `parsesStrongTextAfterChineseWithoutWhitespace` |
| 85 | 行内 | 多个回退加粗段 | 多段加粗 | 解析 | 全部识别 | P1 | ✅ 已覆盖 | `parsesMultipleFallbackStrongSegments` |
| 86 | 行内 | CJK 后标点起始的加粗段 | 标点起始定界 | 解析 | 正确识别 | P1 | ✅ 已覆盖 | `parsesPunctuationStartedStrongSegmentsAfterCJKText` |
| 87 | 行内 | 未闭合加粗定界降级为纯文本 | `**未闭合` | 解析 | 按字面输出 | P0 | ✅ 已覆盖 | `preservesUnclosedStrongDelimiterAsPlainText` |
| 88 | 行内 | 空加粗定界降级为纯文本 | `****` | 解析 | 按字面输出 | P1 | ✅ 已覆盖 | `preservesEmptyStrongDelimiterAsPlainText` |
| 89 | 行内 | 纯空白加粗定界降级为纯文本 | `**  **` | 解析 | 按字面输出 | P1 | ✅ 已覆盖 | `preservesWhitespaceOnlyStrongDelimiterAsPlainText` |
| 90 | 行内 | 原生可解析时不改动 | 常规加粗 | 解析 | 与原生结果一致 | P0 | ✅ 已覆盖 | `preservesNativeMarkdownParsingWhenItAlreadyWorks` |
| 91 | 行内 | 原生行内代码不改动 | 常规行内代码 | 解析 | 与原生一致 | P0 | ✅ 已覆盖 | `preservesNativeInlineCodeParsingWhenItAlreadyWorks` |
| 92 | 行内 | 原生链接解析不改动 | 常规链接 | 解析 | 与原生一致 | P0 | ✅ 已覆盖 | `preservesNativeLinkParsingWhenItAlreadyWorks` |
| 93 | 行内 | 无 Markdown 时保持纯文本 | 纯文本 | 解析 | 原样输出 | P1 | ✅ 已覆盖 | `preservesPlainTextWhenNoMarkdownExists` |
| 94 | 引用 | 解析后引用文本无多余换行 | 单行引用 | 解析 | 前后无 `\n` | P1 | ✅ 已覆盖 | `parsedQuoteTextHasNoSurroundingNewlines` |
| 95 | 引用 | 多行引用无多余空行 | 多行引用 | 解析 | 无额外空行 | P1 | ✅ 已覆盖 | `parsedMultiLineQuoteTextHasNoExtraBlankLines` |
| 96 | 引用 | 引用后接段落产生两个 block | 「引用+段落」 | 解析 | 切分为 2 个 block | P1 | ✅ 已覆盖 | `parsedQuoteFollowedByParagraphProducesTwoBlocks` |
| 97 | 引用 | 引用块不高于等价段落 | 同内容对比 | 度量高度 | 引用块高度 ≤ 段落高度 | P0 | ✅ 已覆盖 | `quoteBlockIsNotTallerThanEquivalentParagraph` |
| 98 | 引用 | 气泡内引用不高于等价段落 | 气泡容器对比 | 度量高度 | 不更高 | P0 | ✅ 已覆盖 | `quoteInBubbleIsNotTallerThanEquivalentParagraph` |
| 99 | 引用 | 列表内引用不高于等价段落 | 列表容器对比 | 度量高度 | 不更高 | P0 | ✅ 已覆盖 | `quoteInListIsNotTallerThanEquivalentParagraph` |
| 100 | 引用 | 引用块无过多垂直空白 | 单容器 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `quoteBlockDoesNotCreateExcessiveVerticalWhitespace` |
| 101 | 引用 | 气泡内引用无过多空白 | 气泡容器 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `quoteInBubbleDoesNotCreateExcessiveVerticalWhitespace` |
| 102 | 引用 | 列表内引用无过多空白 | 列表容器 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `quoteInListDoesNotCreateExcessiveVerticalWhitespace` |
| 103 | 引用 | 引用后接段落无过多空白 | 「引用+段落」 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `quoteFollowedByParagraphDoesNotCreateExcessiveVerticalWhitespace` |
| 104 | 引用 | 引用后接代码块无过多空白 | 「引用+代码块」 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `quoteFollowedByCodeBlockDoesNotCreateExcessiveVerticalWhitespace` |
| 105 | 引用 | 气泡内长引用无过多空白 | 长引用 + 气泡 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `longQuoteInBubbleDoesNotCreateExcessiveVerticalWhitespace` |
| 106 | 引用 | 列表内长引用无过多空白 | 长引用 + 列表 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `longQuoteInListDoesNotCreateExcessiveVerticalWhitespace` |
| 107 | 引用 | 整条消息内引用无过多空白 | 完整消息容器 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `quoteInFullMessageDoesNotCreateExcessiveVerticalWhitespace` |
| 108 | 引用 | 列表行内引用无过多空白 | 列表行容器 | 度量 | 空白在阈值内 | P1 | ✅ 已覆盖 | `quoteInListRowDoesNotCreateExcessiveVerticalWhitespace` |
| 109 | 流式 | 按 block 边界切分与全量解析等价 | 多 block 文档 | 切分后拼接 | 与 `parse` 结果相同 | P0 | ✅ 已覆盖 | `splitAtBlockBoundariesEqualsFullParse` |
| 110 | 流式 | 流式追加每步匹配全量解析 | 逐块追加 | 每步比较 | 每一步都与全量解析一致 | P0 | ✅ 已覆盖 | `streamingAppendMatchesFullParseAtEachStep` |

> 说明：全部 **110 条场景**已在 macOS 上实跑通过。
>
> 本包的价值集中在**回归锁定**，几条易错约定已在用例里显式锁定：
> - **表格规整的误判面比正确面更危险**（ID 39/41/42/46/53/54）：shell 管道
>   `a | b`、TypeScript 联合类型 `string | number` 都不是表格。把它们当表格处理会
>   整段吃掉代码块的高亮与换行，而这在真实对话里极常见——LLM 输出代码的概率很高。
>   反过来，围栏代码块内**确实是**表格的内容也不能被规整（ID 53/54），
>   两个方向都必须有断言。
> - **原生解析是主路径，回退是补丁**（ID 90/91/92 vs 84/85/86）：
>   `swift-markdown` 已能正确处理加粗/行内代码/链接，此时**不得**改动其结果；
>   回退仅针对 `中文**加粗**` 这类 CJK 紧邻场景。若让回退优先，
>   常规英文 Markdown 会走上更弱的自研解析器。
> - **未闭合定界必须降级而非吞字**（ID 87/88/89）：流式输出中途用户看到的是
>   半截 `**`，此时若报错或丢弃，用户会丢失内容。降级为字面输出是唯一正确选择。
> - **尺寸缓存的量化是为压制测量风暴**（ID 68/69 vs 74）：流式渲染时宽度抖动几像素
>   很常见，若每次都重新测量 `NSHostingView` 会造成明显卡顿。量化到 16pt 桶后
>   同桶复用；但内容增长必须逐 token 失效，否则高度永远停在初始值。
> - **多行代码块在聊天列表被截断**（ID 60/64/65/80/82）：根因是
>   `HorizontalScrollView` 的 `heightAnchor` 约束锁死 hostingView 高度，
>   且缺少 `sizeThatFits` 向 SwiftUI 报告真实内容高度。这条回归在
>   `preferOuterScroll` + `List` 组合下才会出现，因此专门有 `MarkdownChatListLayoutTests`。
> - **流式解析必须与全量解析逐步等价**（ID 109/110）：分段解析与一次性解析走
>   不同代码路径，若不等价，用户会在流式过程中看到段落错位或代码块闪烁。
> - **引用块的 12 条空白断言**（ID 97–108）横跨 bubble / list / listRow /
>   full-message 四种容器：同一份引用内容在不同容器里的 padding 与 spacing 叠加
>   方式不同，只测一种容器会漏掉其余三种的空白问题。

## 覆盖率统计

- P0: 已覆盖 42 / 42
- P1: 已覆盖 66 / 66
- P2: 已覆盖 2 / 2
- **合计: 110 / 110**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 模型相等性、空/纯空白文档、多行代码块完整性、复杂文档解析、
  表格规整的正误判双向（竖线段落、shell 管道、TS 联合、转义竖线、围栏内表格、
  非法分隔行回退）、代码块不被截断与不塌陷、聊天滚动高度一致性、
  尺寸缓存命中与失效、CJK 加粗与未闭合定界、原生解析不被改动、流式等价
- **P1**: 其余解析形态（标题层级、列表、表格对齐、Mermaid 识别）、
  尺寸缓存分桶与共享 store、异步布局稳定性、引用块切分与空白、行内回退分支
- **P2**: `thematicBreak` 相等性、共享 store 容量淘汰

## 跨平台说明

- Package 声明 macOS 14+ / iOS 17+
- `KitMarkdownCoreTests`（ID 1–56）为**跨平台**：纯 Foundation 解析逻辑
- `KitMarkdownTests`（ID 57–110）依赖 SwiftUI/AppKit 布局度量
  （`NSHostingView` / `HorizontalScrollView` / `NSScrollView`），
  涉及真实测量高度的断言（ID 59–66、77–83、97–108）为 **macOS 专属**
- 所有布局度量类用例依赖宿主窗口环境，`KitMarkdownTesting` 提供统一支撑；
  跨平台运行时应跳过这些用例而非放宽阈值

## 测试执行

```bash
cd Packages/KitMarkdown

# 全部测试
swift test

# 仅纯解析层（跨平台）
swift test --filter KitMarkdownCoreTests
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
   （ID 60 即「多行代码块在聊天列表被垂直截断」的回归）
3. **删除用例** → 在 commit message 说明理由；**表格误判类用例
   （ID 39/41/42/53/54）不得删除**，它们是防止「顺手放宽表格识别」的屏障
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **原生优先原则** → 改动行内解析前先确认 `swift-markdown` 是否已能处理；
   自研回退仅用于 CJK 紧邻场景，且必须保证 ID 90/91/92 仍然通过
6. **包结构变更** → 本包用 `path: "."` + `sources:` 显式指定目录（`KitMarkdownCore`
   取 `Models`/`Parsers`，`KitMarkdown` 取 `Mermaid`/`Views`），
   不符合项目通用的 `Sources/<PackageName>/` 包裹目录约定。
   若改为标准布局，须同步 `Package.swift` 的 `path`/`sources`/`exclude` 与本 TestPlan 的包概述
