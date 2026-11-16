# TestPlan — PluginHostsManager

## 包概述

PluginHostsManager 的实现包，包含 7 个主要类型；当前测试覆盖 34 条用例。

平台: macOS 14+, iOS 17+
测试文件: 8 个，用例总数: 34

核心组件（源码目录）:
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `HostsManagerPlugin`
- `HostEntryType`
- `HostsFileService`
- `HostsManagerViewModel`
- `HostsManagerAboutView`
- `HostsManagerManualView`
- `HostsManagerView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **HostsFileService**（7 条）：由 `readsAndBacksUpHostsFile`、`reportsMissingHostsFile`、`removesTemporaryFileWhenInstallFails`、`removesTemporaryFileAfterSuccessfulInstall`、`backupRunsOffMain`、`backupWriteFailureThrows`、`importReadRunsOffMain` 锁定备份/导入 I/O 必须在后台线程执行、备份写入失败必须抛错而不是静默失败（**回归 #1208**）；改动该模块时优先跑对应测试文件。
- **HostsManagerFileFlow**（2 条）：由 `loadsAndSavesThroughInjectedFileOperations`、`reportsFileOperationFailures` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HostsManagerViewModel**（4 条）：由 `filtersByGroupAndSearch`、`rejectsInvalidEntry`、`mutatesEntriesAndPersists`、`reloadReconcilesSelectedGroup` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HostsManagerViewModel 保存串行化**（2 条）：由 `newestSnapshotWinsWhenFirstWriteIsDelayed`、`staleSaveSkipsReload` 锁定并发保存按请求顺序串行落盘（最新快照最后写入）、过期世代不得用旧内容 reload 覆盖最新 entries（**回归 #254**）；改动保存/重载路径时优先跑对应测试文件。
- **HostsToggleOffMain**（3 条）：由 `parseAndSerializeRunOffMain`、`staleLoadDoesNotOverwriteNewerEntries`、`toggleWritesToggledSnapshot` 锁定解析/序列化在后台线程执行且往返一致、晚到的旧加载不得覆盖最新 entries、切换条目后落盘的是切换后的快照（**回归 #1205**）；改动开关/加载/保存路径时优先跑对应测试文件。
- **HostsManagerViewModel Retry**（3 条）：由 `retryAfterFailedSaveResavesAndKeepsEdits`、`retryAfterFailedLoadReloadsFromDisk`、`validationErrorDoesNotDowngradePendingSaveRetry` 锁定。错误横幅的 Retry 必须按最近一次失败的操作类型分派：保存失败重试保存以保留内存中未落盘的编辑，不得 reload 磁盘旧内容把它们静默丢弃；加载失败才重新加载（**回归 #458**）。改动保存/重载/错误横幅路径时优先跑对应测试文件。
- **HostsParser**（9 条）：由 `parsesActiveEntries`、`parsesCommentsAndGroups`、`preservesBlankLines`、`parsesAbsoluteDomainAsActiveEntry`、`acceptsAbsoluteDomainWithTrailingRootDot`、`preservesUnrecognizedActiveLineVerbatim` 等用例锁定合法绝对域名（末尾根点）必须解析为启用条目、ASCII 语法外的活动行必须逐字保留且不得在保存时被注释禁用（**回归 #255**）；改动该模块时优先跑对应测试文件。
- **综合**（3 条）：由 `pluginMetadataIsStable`、`localizationCatalogIsPackaged`、`activatingPluginHidesChatSectionAndDeactivatingRestoresIt` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | HostsFileService | reads and backs up an injected hosts file | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsAndBacksUpHostsFile` |
| 2 | HostsFileService | propagates missing hosts-file read errors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsMissingHostsFile` |
| 3 | HostsManagerFileFlow | loads entries, saves their serialization, and reloads the saved content | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsAndSavesThroughInjectedFileOperations` |
| 4 | HostsManagerFileFlow | surfaces read and write failures and clears loading state | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsFileOperationFailures` |
| 5 | HostsManagerViewModel | filters entries by group and only shows groups that contain search matches | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filtersByGroupAndSearch` |
| 6 | HostsManagerViewModel | rejects invalid new entries without mutating the list | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidEntry` |
| 7 | HostsManagerViewModel | adds, toggles, and deletes entries through the save and reload flow | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mutatesEntriesAndPersists` |
| 8 | HostsParser | parses active IPv4 and IPv6 entries with inline comments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesActiveEntries` |
| 9 | HostsParser | distinguishes disabled entries, ordinary comments, and group headers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesCommentsAndGroups` |
| 10 | HostsParser | preserves intentional blank lines and omits only the terminal newline sentinel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesBlankLines` |
| 11 | HostsParser | validates IPv4, IPv6, and domain labels | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `validatesAddressesAndDomains` |
| 12 | HostsParser | normalizes a whitespace-separated domain list | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizesDomainList` |
| 13 | HostsParser | serializes entries to a representation that parses back without data loss | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `serializationRoundTrips` |
| 14 | 综合 | pluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 15 | 综合 | localizationCatalogIsPackaged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizationCatalogIsPackaged` |
| 16 | 综合 | activatingPluginHidesChatSectionAndDeactivatingRestoresIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginHidesChatSectionAndDeactivatingRestoresIt` |
| 17 | 综合 | ungroupedEntryStaysBeforeFirstGroup | — | 执行该用例 | 空分组条目保存后位于首个 group header 之前，且不进入该组筛选 | P0 | ✅ 已覆盖 | `ungroupedEntryStaysBeforeFirstGroup` |
| 18 | HostsManagerViewModel | 刷新后清理已不存在的分组筛选，保留仍存在的选择 | 注入可切换内容的 hosts 文件 | 选中 Old 后重载为仅含 New 的配置，再选中保留分组重载 | 旧分组消失时 `selectedGroup` 归 nil 且新条目可见；分组仍在时保留选择 | P0 | ✅ 已覆盖 | `reloadReconcilesSelectedGroup` |
| 19 | HostsFileService | 特权安装失败或取消授权时删除临时 hosts 副本（**回归 #256**） | 注入 install 闭包抛错模拟取消 | 调用 `withTemporaryHostsFile`，闭包内确认副本存在后抛错 | 错误透传给调用方，且临时文件不再存在 | P0 | ✅ 已覆盖 | `removesTemporaryFileWhenInstallFails` |
| 20 | HostsFileService | 特权安装成功后同样删除临时 hosts 副本（**回归 #256**） | 注入正常返回的 install 闭包 | 调用 `withTemporaryHostsFile`，闭包内确认副本存在 | 返回后临时文件不再存在 | P1 | ✅ 已覆盖 | `removesTemporaryFileAfterSuccessfulInstall` |
| 21 | HostsParser | parses a legal absolute domain (trailing root dot) as an active entry, not a comment（**回归 #255**） | hosts 含 `127.0.0.1 example.com.` | 解析后再序列化 | 仍为启用的 `.entry`，序列化原文不变，不被写成注释 | P0 | ✅ 已覆盖 | `parsesAbsoluteDomainAsActiveEntry` |
| 22 | HostsParser | accepts a single trailing root dot but rejects double dots and root-only（**回归 #255**） | — | 调用 `isValidDomain` | `example.com.`/`localhost.` 通过；`example.com..`/`.` 拒绝 | P1 | ✅ 已覆盖 | `acceptsAbsoluteDomainWithTrailingRootDot` |
| 23 | HostsParser | keeps an unrecognized active line verbatim and enabled across save (must not comment it out)（**回归 #255**） | hosts 含 ASCII 语法外的合法别名（如 IDN `例子.com`） | 解析→序列化→再解析 | 原文逐字保留、不加 `# ` 前缀、保持启用，往返稳定 | P0 | ✅ 已覆盖 | `preservesUnrecognizedActiveLineVerbatim` |
| 24 | HostsManagerViewModel | serializes concurrent saves so the newest snapshot is written last（**回归 #254**） | 注入可挂起首次写入的 hosts 文件 | E1 写入挂起时做 E2，再放行 E1 的迟到写入 | 磁盘最终内容含 first.test 与 second.test（最新快照最后落盘），entries 含两条 | P0 | ✅ 已覆盖 | `newestSnapshotWinsWhenFirstWriteIsDelayed` |
| 25 | HostsManagerViewModel | a stale save does not reload old content over the newest entries（**回归 #254**） | 注入挂起每次写入的 hosts 文件 | E1 挂起→E2→放行 S1（S2 随即挂起） | 过期保存跳过 reload，entries 仍含 second.test 与 first.test | P0 | ✅ 已覆盖 | `staleSaveSkipsReload` |
| 26 | HostsManagerViewModel | 保存失败后 Retry 必须重试保存，不得用磁盘旧内容丢弃未落盘编辑（**回归 #458**） | 注入首次写入失败的 hosts 文件替身 | 加载→addEntry 触发保存失败→调用 `retry()` | 再次写入（writes=2）、磁盘含 kept.test、entries 保留该编辑、errorMessage 清空 | P0 | ✅ 已覆盖 | `retryAfterFailedSaveResavesAndKeepsEdits` |
| 27 | HostsManagerViewModel | 加载失败后 Retry 重新从磁盘加载，不触发保存 | 注入首次读取失败的 hosts 文件替身 | 加载失败→调用 `retry()` | 第二次读取成功（reads=2）、无写入、entries 含 disk.test、errorMessage 清空 | P1 | ✅ 已覆盖 | `retryAfterFailedLoadReloadsFromDisk` |
| 28 | HostsManagerViewModel | 校验错误不得把待重试的保存降级为重新加载（**回归 #458**） | 保存失败后内存仍有未落盘编辑 | 再触发一次非法 addEntry 校验错误→调用 `retry()` | 仍重试保存（writes=2）、磁盘含 kept.test、编辑不丢失 | P0 | ✅ 已覆盖 | `validationErrorDoesNotDowngradePendingSaveRetry` |
| 29 | HostsFileService | 备份读取/写入在后台线程执行，不占用主线程（**回归 #1208**） | 临时 hosts 源文件与备份目标 | 在 `Task.detached` 中调用 `backupSync`，同步 helper 记录 `Thread.isMainThread` | 标志为 false（非主线程），备份内容与源一致 | P1 | ✅ 已覆盖 | `backupRunsOffMain` |
| 30 | HostsFileService | 备份写入失败必须抛错而不是静默失败（**回归 #1208**） | 备份目标位于不存在的目录 | 调用 `backupSync` | 抛出错误，不静默吞掉 | P0 | ✅ 已覆盖 | `backupWriteFailureThrows` |
| 31 | HostsFileService | 导入内容读取/解码在后台线程执行（**回归 #1208**） | 临时备份文件 | 在 `Task.detached` 中调用 `readTextFile`，记录是否主线程 | 标志为 false，读取内容与文件一致 | P1 | ✅ 已覆盖 | `importReadRunsOffMain` |
| 32 | HostsToggleOffMain | 解析与序列化在后台线程执行且往返一致（**回归 #1205**） | 含分组/启用/禁用条目的 hosts 文本 | 在 `Task.detached` 中 parse→serialize，记录是否主线程 | 标志为 false，往返结果与原文一致 | P1 | ✅ 已覆盖 | `parseAndSerializeRunOffMain` |
| 33 | HostsToggleOffMain | 晚到的旧加载不得覆盖最新 entries（**回归 #1205**） | 注入首次读取挂起的 hosts 文件 | L1 挂起时发起 L2 并先完成，再放行 L1 | entries 仍含 second.test、不含 first.test，isLoading 为 false | P0 | ✅ 已覆盖 | `staleLoadDoesNotOverwriteNewerEntries` |
| 34 | HostsToggleOffMain | 切换条目后落盘的是切换后的快照（**回归 #1205**） | 注入记录写入的 hosts 文件，含一条启用条目 | 加载后调用 `toggleEntry` | 首次写入为该条目被注释禁用后的序列化（`# 127.0.0.1 app.test`） | P1 | ✅ 已覆盖 | `toggleWritesToggledSnapshot` |

> 说明：全部 **34 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> 第 29–34 行为补登记：#1205/#1208 的 off-main 用例此前已在源码中实跑，但漏登记到本表，一并补齐以通过校验闸门。

> 变异验证（#458）：把 `retry()` 改回修复前的「无条件 `await loadHosts()`」后，`retryAfterFailedSaveResavesAndKeepsEdits`、`validationErrorDoesNotDowngradePendingSaveRetry` 转红（Retry 用磁盘旧内容覆盖内存，writes 停在 1、kept.test 编辑丢失），`retryAfterFailedLoadReloadsFromDisk` 保持绿；恢复按 `retryAction` 分派后全部 34 条通过。

## 覆盖率统计

- P0: 已覆盖 13 / 13
- P1: 已覆盖 19 / 19
- P2: 已覆盖 2 / 2
- **合计: 34 / 34**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（13 条）
- **P1**: 其余功能性用例（19 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 34 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginHostsManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
