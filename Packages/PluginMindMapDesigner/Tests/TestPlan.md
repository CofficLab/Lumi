# TestPlan — PluginMindMapDesigner

## 包概述

PluginMindMapDesigner 的实现包，包含 14 个主要类型；当前测试覆盖 33 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 33

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Tools/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MindMapDesignerPlugin`
- `MindMapDesignerSkillContributor`
- `MindMapNode`
- `MindMapProjectObserver`
- `MindMapScope`
- `MindMapFileStore`
- `MindMapNodeLayout`
- `MindMapLocalization`
- `MindMapMarkdownCodec`
- `MindMapStore`
- `AddChildNodeTool`
- `CreateMindMapTool`
- `DeleteNodeTool`
- `ExportMindMapTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MindMapDesignerPlugin**（11 条）：由 `contributesRailTabAndCompleteToolSet`、`activatingPluginShowsChatSectionAndDeactivatingRestoresIt`、`markdownCodecRoundTrip` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MindMapMarkdownCodec 健壮性**（9 条）：由 `ignoresPlainTextAfterRoot`、`ignoresHeadingAfterRoot`、`emptyOutlineProducesFallbackRoot` 等用例锁定；改动大纲解析的层级与容错逻辑时优先跑对应测试文件。
- **MindMapStore 写前同步**（3 条）：由 `writeDoesNotClobberNodesAddedElsewhere`、`createDoesNotDropExistingMaps`、`deleteUsesDiskState` 等用例锁定；改动 store 的读写顺序或缓存策略时优先跑对应测试文件。
- **MindMapConversationScope**（7 条）：由 `conversationScopedToolReadsFromItsOwnProject`、`crossProjectWriteDoesNotPolluteSharedStore` 等用例锁定；改动会话作用域隔离时优先跑对应测试文件。
- **MindMapStore 删除失败**（2 条）：由 `failedDeleteKeepsMapInList`、`fallbackDeleteThrowsWhenFileCannotBeRemoved` 用例锁定；目录不可写导致文件删不掉时，`MindMapFileStore.delete` 必须抛错，`MindMapStore` 保留列表项与选中项并写入 `lastError`，不得提交内存删除。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MindMapDesignerPlugin | contributesRailTabAndCompleteToolSet | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contributesRailTabAndCompleteToolSet` |
| 2 | MindMapDesignerPlugin | activatingPluginShowsChatSectionAndDeactivatingRestoresIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginShowsChatSectionAndDeactivatingRestoresIt` |
| 3 | MindMapDesignerPlugin | markdownCodecRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `markdownCodecRoundTrip` |
| 4 | MindMapDesignerPlugin | layoutEngineProducesPositions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `layoutEngineProducesPositions` |
| 5 | MindMapDesignerPlugin | descendantIds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `descendantIds` |
| 6 | MindMapDesignerPlugin | wouldCreateCycle | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `wouldCreateCycle` |
| 7 | MindMapDesignerPlugin | agentToolsBuildAndGrowMapInProjectScope | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `agentToolsBuildAndGrowMapInProjectScope` |
| 8 | MindMapDesignerPlugin | mapsCannotBeCreatedWithoutAnOpenProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mapsCannotBeCreatedWithoutAnOpenProject` |
| 9 | MindMapMarkdownCodec 健壮性 | 根节点之后的普通文本被忽略而不崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ignoresPlainTextAfterRoot` |
| 10 | MindMapMarkdownCodec 健壮性 | 根节点之后的标题行被忽略而不崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ignoresHeadingAfterRoot` |
| 11 | MindMapMarkdownCodec 健壮性 | 列表项之间的普通文本被忽略而不崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ignoresPlainTextBetweenListItems` |
| 12 | MindMapMarkdownCodec 健壮性 | 纯文本大纲仍能创建根节点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `plainTextOutlineStillCreatesRoot` |
| 13 | MindMapMarkdownCodec 健壮性 | 空大纲得到一个兜底根节点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyOutlineProducesFallbackRoot` |
| 14 | MindMapConversationScope | 加入项目不预建存储目录，真正写入时才创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotCreateStorageDirectoryUntilWrite` |
| 15 | MindMapConversationScope | 会话作用域的工具只读取自己项目的导图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationScopedToolReadsFromItsOwnProject` |
| 16 | MindMapConversationScope | 会话作用域的工具只写入自己项目的导图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationScopedToolWritesIntoItsOwnProject` |
| 17 | MindMapConversationScope | 跨项目写入不会污染共享存储 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crossProjectWriteDoesNotPolluteSharedStore` |
| 18 | MindMapConversationScope | 注册的工具都按会话解析作用域 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registeredToolsAreConversationScoped` |
| 19 | MindMapConversationScope | 未绑定作用域的会话回退到当前项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unscopedConversationFallsBackToCurrentProject` |
| 20 | MindMapConversationScope | 同一项目复用同一份存储 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameProjectReusesSharedStore` |
| 21 | MindMapStore 写前同步 | 写操作前与磁盘对齐，不覆盖别处新增的节点 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `writeDoesNotClobberNodesAddedElsewhere` |
| 22 | MindMapStore 写前同步 | 新建导图不会挤掉磁盘上已有的导图 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createDoesNotDropExistingMaps` |
| 23 | MindMapStore 写前同步 | 删除别处创建的导图时以磁盘状态为准 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `deleteUsesDiskState` |
| 24 | MindMapConversationScope | 列表返回完整 ID 且可直接用于加载（**回归 #1001**） | 项目中一张导图，list → 取 `[id]` → load | 依次调用 `list_mind_maps`、`load_mind_map` | 发现的 ID 等于完整 UUID，加载结果包含标题 | P0 | ✅ 已覆盖 | `listedIdentifierCanBeLoadedDirectly` |
| 25 | MindMapStore 删除失败 | 删除文件失败时保留列表项与选中项并报告错误（**回归 #1061**） | 已加载一张导图，并将存储目录设为只读 | 调用 `deleteMindMap` 后再 reload | 列表与选中项保持不变，`lastError` 非空，文件仍在且重载后可见 | P1 | ✅ 已覆盖 | `failedDeleteKeepsMapInList` |
| 26 | MindMapStore 删除失败 | 标题与磁盘不一致走兜底删除时失败同样抛错（**回归 #1061**） | 磁盘文件标题与内存标题不同，存储目录只读 | 调用 `MindMapFileStore.delete` | 抛错且文件仍在 | P1 | ✅ 已覆盖 | `fallbackDeleteThrowsWhenFileCannotBeRemoved` |
| 27 | MindMapDesignerPlugin | 地图数量变化同步 Rail 可见性（**回归 #1020**） | 项目内无导图 | 空列表、创建首张、删除最后一张后各触发一次可用性通知 | Rail 依次隐藏、显示、隐藏 | P1 | ✅ 已覆盖 | `mapAvailabilityChangesUpdateRailVisibility` |
| 28 | MindMapMarkdownCodec 健壮性 | 显式 title 不被 Markdown 标题覆盖（**回归 #1082**） | — | 解码 `# Source Heading\n- Branch` 并传 `title: "Custom Title"` | 地图标题与根节点均为 `Custom Title`，`Source Heading` 不成为节点 | P0 | ✅ 已覆盖 | `explicitTitleWinsOverHeading` |
| 29 | MindMapMarkdownCodec 健壮性 | 空白 title 回退到 Markdown 首个标题 | — | 解码同一大纲并传 `title: "   "` | 地图标题与根节点均为 `Source Heading` | P1 | ✅ 已覆盖 | `blankTitleFallsBackToHeading` |
| 30 | MindMapMarkdownCodec 健壮性 | 同级 Tab 缩进生成兄弟节点（**回归 #1081**） | — | 解码 `- A` 下两个以 Tab 缩进的 `A1`/`A2` | 两者 `parentId` 均为 `A`，不形成 `A1 → A2` 链 | P1 | ✅ 已覆盖 | `tabIndentedSiblingsStaySiblings` |
| 31 | MindMapMarkdownCodec 健壮性 | Tab 与两空格缩进产生相同结构 | — | 分别解码同一大纲的 Tab 版与两空格版 | 两版节点父子关系完全一致 | P1 | ✅ 已覆盖 | `tabAndSpaceIndentationProduceSameShape` |
| 32 | MindMapDesignerPlugin | `save_mind_map` 重建缺失的 backing JSON（**回归 #1080**） | 地图已在内存，JSON 文件被删除 | 调用 `save_mind_map(mapId:)` | 返回成功且磁盘重新出现该地图，内存列表仍包含它 | P0 | ✅ 已覆盖 | `saveMindMapRecreatesMissingBackingFile` |
| 33 | MindMapDesignerPlugin | `save_mind_map` 写入失败必须抛错（**回归 #1080**） | 地图已创建，存储目录路径被普通文件占据 | 调用 `save_mind_map(mapId:)` | 抛出错误，不返回保存成功 | P0 | ✅ 已覆盖 | `saveMindMapReportsWriteFailure` |

> 说明：全部 **33 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 23 / 23
- P2: 已覆盖 0 / 0
- **合计: 33 / 33**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（23 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 33 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMindMapDesigner
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
