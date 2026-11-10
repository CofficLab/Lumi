# TestPlan — PluginClipboardManager

## 包概述

ClipboardManagerPlugin Manage clipboard history and snippets

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 29

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ClipboardManagerPluginSupport`
- `ClipboardManagerPluginLocalStore`
- `ClipboardManagerRuntime`
- `ClipboardHistoryItem`
- `ClipboardItemType`
- `ClipboardHistoryChangeCenter`
- `ClipboardMonitorObserver`
- `ClipboardHistoryManager`
- `ClipboardMonitor`
- `ClipboardStorage`
- `ClipboardManagerViewModel`
- `ClipboardHistoryView`
- `ClipboardManagerAboutView`
- `ClipboardManagerManualView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（27 条）：由 `pluginMetadataIsStable`、`activatingPluginHidesChatSectionAndDeactivatingRestoresIt`、`writesTextHistoryItemToPasteboard` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | pluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 2 | 综合 | activatingPluginHidesChatSectionAndDeactivatingRestoresIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginHidesChatSectionAndDeactivatingRestoresIt` |
| 3 | 综合 | writesTextHistoryItemToPasteboard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writesTextHistoryItemToPasteboard` |
| 4 | 综合 | writesImageHistoryItemToPasteboard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writesImageHistoryItemToPasteboard` |
| 5 | 综合 | imageHistoryItemWithMissingFileDoesNotClaimSuccess | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageHistoryItemWithMissingFileDoesNotClaimSuccess` |
| 6 | 综合 | monitorPrefersFileURLsOverStringRepresentations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `monitorPrefersFileURLsOverStringRepresentations` |
| 7 | 综合 | monitorPrefersImageOverFallbackString | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `monitorPrefersImageOverFallbackString` |
| 8 | 综合 | monitorTreatsFileURLStringsAsFiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `monitorTreatsFileURLStringsAsFiles` |
| 9 | 综合 | monitorTreatsUnescapedFileURLStringsAsFiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `monitorTreatsUnescapedFileURLStringsAsFiles` |
| 10 | 综合 | monitorKeepsMixedPathTextAsText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `monitorKeepsMixedPathTextAsText` |
| 11 | 综合 | localStoreSavesAndReloadsSettings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localStoreSavesAndReloadsSettings` |
| 12 | 综合 | localStoreQuarantinesInvalidSettingsFileAndRecovers | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `localStoreQuarantinesInvalidSettingsFileAndRecovers` |
| 13 | 综合 | localStoreReportsFailureWhenSettingsDirectoryIsBlocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localStoreReportsFailureWhenSettingsDirectoryIsBlocked` |
| 14 | 综合 | historyStoreFallsBackWhenDatabaseDirectoryIsBlocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyStoreFallsBackWhenDatabaseDirectoryIsBlocked` |
| 15 | 综合 | historyManagerReportsPersistenceResults | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyManagerReportsPersistenceResults` |
| 16 | 综合 | historyManagerClampsFetchLimitsBeforeQuerying | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyManagerClampsFetchLimitsBeforeQuerying` |
| 17 | 综合 | 长期运行中，列表查询会按需清理过期记录 | 未固定记录超过 30 天且进程未重启 | 仅调用 `getAll()` 读取列表 | 过期未固定项被删除，固定项与新记录保留 | P0 | ✅ 已覆盖 | `listAccessCleansExpiredWithoutRestart` |
| 18 | 综合 | 富文本负载随条目持久化并可读回 | RTF + HTML | 写入后读取存储层 | 两个字段原样返回 | P0 | ✅ 已覆盖 | `preservesRichTextPayloads` |
| 19 | 综合 | 纯文本相同但富文本负载不同时保留为两条 | 同文本、不同 HTML | 连续写入两次 | 存储中有 2 条 | P1 | ✅ 已覆盖 | `keepsSameTextWithDifferentRichPayloads` |
| 20 | 综合 | 纯文本与富文本负载都相同时去重 | 完全相同的两条 | 连续写入两次 | 存储中只有 1 条 | P1 | ✅ 已覆盖 | `deduplicatesIdenticalRichPayloads` |
| 21 | 综合 | 富文本条目回写剪贴板时同时写入 RTF/HTML/纯文本 | 条目带 RTF 与 HTML | 调用 `write(item, to:)` | 三种表示都可从剪贴板取回 | P0 | ✅ 已覆盖 | `writesRichTextHistoryItemToPasteboard` |
| 22 | 综合 | 旧库条目（无富文本字段）回写为纯文本 | 富文本字段为 nil | 调用 `write(item, to:)` | 写入成功，纯文本可读，不写 RTF/HTML | P1 | ✅ 已覆盖 | `writesLegacyTextItemAsPlainText` |
| 23 | 综合 | 监控捕获剪贴板中的 RTF 与 HTML | 剪贴板同时提供三种表示 | 调用 `itemsAsync` | 条目内容为纯文本且携带两个富文本负载 | P0 | ✅ 已覆盖 | `monitorCapturesRichTextRepresentations` |
| 24 | 综合 | 富文本负载超过 1MB 时退化为只存纯文本 | RTF 超过上限 | 构造 `ClipboardItem` | 两个富文本字段为 nil，纯文本保留 | P1 | ✅ 已覆盖 | `oversizedRichTextFallsBackToPlainText` |
| 25 | 综合 | 旧版本数据库可被新模型打开，老条目仍可读 | 用无富文本列的旧模型建库并写入 | 用新模型打开同一文件 | 老条目读出纯文本，富文本字段为 nil | P0 | ✅ 已覆盖 | `opensLegacyDatabaseAfterAddingRichTextColumns` |
| 26 | 综合 | 连续复制同一图片只保留一条记录 | 同一张图片被采集两次、落盘路径不同 | 两次写入存储 | 存储只有 1 条且指向新路径，旧图片文件被删除 | P1 | ✅ 已覆盖 | `deduplicatesIdenticalImageContent` |
| 27 | 综合 | 不同图片内容各自保留 | 两份字节不同的图片文件 | 连续写入两条图片条目 | 存储中有 2 条 | P1 | ✅ 已覆盖 | `keepsDifferentImages` |
| 28 | 综合 | 历史大小设置会裁剪超出的非固定项 | 上限设为 2 | 连续写入 3 条不同记录 | 只保留最新 2 条 | P1 | ✅ 已覆盖 | `respectsConfiguredHistoryLimit` |
| 29 | 综合 | Unlimited 设置不裁剪历史 | 上限设为 Int.max | 连续写入 3 条不同记录 | 3 条全部保留 | P2 | ✅ 已覆盖 | `unlimitedHistorySkipsTrim` |
| 30 | ClipboardHistoryManager | add(ClipboardItem) 走 ClipboardItem → ClipboardHistoryItem 转换并落库 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addsClipboardItem` |
| 31 | ClipboardHistoryManager | addBatch 批量写入后可全部读回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addsBatch` |
| 32 | ClipboardHistoryManager | getAll 按时间倒序返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getAllSortsDescending` |
| 33 | ClipboardHistoryManager | query 按时间区间过滤 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `queriesByTimeRange` |
| 34 | ClipboardHistoryManager | search 命中关键词、不命中返回空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchesByKeyword` |
| 35 | ClipboardHistoryManager | delete(ids:) 批量删除命中项，其余保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deletesBatch` |
| 36 | ClipboardHistoryManager | updatePinStatus 对不存在的 id 返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinUpdateForUnknownIDFails` |
| 37 | ClipboardHistoryManager | delete(id:) 对不存在的 id 返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteForUnknownIDFails` |
| 38 | ClipboardHistoryManager | clearAll(keepPinned: true) 保留固定项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearAllKeepsPinned` |
| 39 | ClipboardHistoryManager | clearAll(keepPinned: false) 清空全部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearAllRemovesEverything` |
| 40 | ClipboardHistoryManager | cleanup 删除超期且未固定的记录，保留超期固定项与新记录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cleanupRemovesExpiredUnpinned` |
| 41 | ClipboardHistoryManager | migrateFromJSON 先清空旧数据再导入新数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `migratesFromJSON` |
| 42 | ClipboardHistoryManager | 数据库目录被文件占用时隔离该文件并重建目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quarantinesFileBlockingDatabaseDirectory` |
| 43 | Clipboard models | ClipboardItem.title 按类型派生 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `clipboardItemTitle` |
| 44 | Clipboard models | ClipboardItem 初始化时把搜索关键词转小写 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `clipboardItemLowercasesKeywords` |
| 45 | Clipboard models | ClipboardHistoryItem 初始化时把搜索关键词转小写 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `historyItemLowercasesKeywords` |
| 46 | Clipboard models | ClipboardHistoryItem → ClipboardItem 往返保留核心字段 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `historyItemRoundTrips` |
| 47 | Clipboard models | 未知类型字符串回退为 text | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownTypeFallsBackToText` |
| 48 | ClipboardStorage | add 后可通过 getItems / getLatest 读回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storesItems` |
| 49 | ClipboardStorage | 连续添加相同内容时移除旧的未固定项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deduplicatesConsecutiveContent` |
| 50 | ClipboardStorage | 内容相同但类型不同不去重 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsDifferentTypes` |
| 51 | ClipboardStorage | 已有项被固定时，重复内容不去重 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsPinnedDuplicate` |
| 52 | ClipboardStorage | togglePin 翻转固定状态，未知 id 为空操作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `togglesPin` |
| 53 | ClipboardStorage | clear 默认保留固定项 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `clearsKeepingPinnedByDefault` |
| 54 | ClipboardStorage | clear(keepPinned: false) 清空全部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearsEverything` |
| 55 | ClipboardStorage | delete(id:) 与 delete(ids:) 删除对应项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deletesItems` |
| 56 | ClipboardStorage | search 与 query 走历史管理器过滤 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchesAndQueries` |
| 57 | ClipboardStorage | migrateFromJSON 覆盖历史数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `migratesFromJSON` |
| 58 | ClipboardManagerViewModel | loadItems 拉取存储层数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsItems` |
| 59 | ClipboardManagerViewModel | filterItems 按搜索词过滤，空搜索词返回全部 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filtersItems` |
| 60 | ClipboardManagerViewModel | delete / togglePin / clearAll 变更后刷新列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mutatesAndRefreshes` |
| 61 | ClipboardManagerViewModel | write 按类型写入不同剪贴板表示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writesToPasteboard` |
| 62 | Clipboard history change center | 注册观察者后 notify 会回调，取消后不再回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `notifiesAndCancels` |
| 63 | Clipboard history change center | 多个观察者各自收到通知 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `notifiesAllObservers` |
| 64 | Clipboard history change center | ClipboardHistoryObserver 把变化转发给回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerForwardsChanges` |
| 65 | ClipboardManagerRuntimeTests | 注入目录后 databaseDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesInjectedDatabaseDirectory` |
| 66 | ClipboardManagerRuntimeTests | 未注入目录时守卫拒绝回退到真实数据目录 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `refusesFallbackWithoutInjection` |

> 说明：全部 **66 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 51 / 51
- P2: 已覆盖 9 / 9
- **合计: 66 / 66**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（51 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（9 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 66 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginClipboardManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
