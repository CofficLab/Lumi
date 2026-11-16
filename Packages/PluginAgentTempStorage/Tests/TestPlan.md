# TestPlan — PluginAgentTempStorage

## 包概述

PluginAgentTempStorage 的实现包，包含 7 个主要类型；当前测试覆盖 33 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 33

核心组件（源码目录）:
- `Services/`
- `Store/`
- `Tools/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentTempStoragePlugin`
- `AgentTempStoragePluginRuntimeBridge`
- `TempFileInfo`
- `AgentTempStoragePluginLocalStore`
- `ListTempFilesTool`
- `ReadTempFileTool`
- `WriteTempFileTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentTempStorageRuntimeBridge**（3 条）：由 `injectedDirectoryResolvesToInjectedDirectory`、`sharedStorageUsesInjectedDirectory`、`refusesFallbackWithoutInjection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（16 条）：由 `pluginMetadataIsStable`、`pluginRegistersThreeTools`、`toolsAreLowRisk`、`unreadableSettingsAbortPurgeAndSurfaceError` 等用例锁定；其中 `storageSupportsNestedReadWriteAndList` 锁定列表必须递归枚举嵌套文件，`purgeRemovesExpiredNestedFiles` 锁定清理必须递归删除过期嵌套文件（#200）；改动该模块时优先跑对应测试文件。
- **TempFileStorageSymlink**（6 条）：由 `writeRejectsFileSymlinkPointingOutsideStorage`、`readRejectsFileSymlinkPointingOutsideStorage`、`writeRejectsNestedPathThroughSymlinkDirectory` 等用例锁定（#232）：路径边界检查必须解析符号链接，指向存储外部的文件/目录链接不得越界读写；指向内部的链接保持可用，经悬空链接目录写入必须失败且无外部副作用。改动 `resolveSafeURL` 时优先跑 `TempFileStorageSymlinkTests.swift`。
- **点文件可见且可清理**（2 条）：由 `listsAndReadsRootDotfile`、`purgeRemovesExpiredRootDotfile` 锁定（**回归 #327**）：`.audit.txt` 这类点文件是合法临时文件，可写可读；`listFiles` 与 `purgeExpiredFiles` 的枚举都不得用 `.skipsHiddenFiles`，否则点文件可读写却永远不可见、过期也永不删除。改动两处枚举 options 时优先跑对应用例。
- **列表枚举失败必须抛错**（2 条）：由 `listFilesThrowsWhenDirectoryCannotBeEnumerated`、`listFilesReturnsEmptyForReadableEmptyDirectory` 锁定（**回归 #511**）：`FileManager.enumerator` 对打不开的目录返回空序列而非 nil，`listFiles` 必须用 `errorHandler` 捕获失败并抛 `listFailed`，只有成功读取的空目录才返回空列表。改动 `listFiles` 枚举时优先跑对应用例。
- **数据迁移保留天数导入**（5 条）：由 `importsRetentionDaysWhenOnlyVersionedDirectoryExists`、`importsRetentionDaysWhenNoLegacyDirectoryExists`、`mergesUnversionedDirectoryAndStillImports` 等用例锁定（**回归 #811**）：旧 UserDefaults 保留天数是独立于旧文件目录的配置，`migrateData` 无论无版本旧目录是否存在都必须执行 `importLegacyRetentionDays`；已有 settings.plist 不被覆盖，无旧值时保持默认。改动 `migrateData` 的目录守卫或导入顺序时优先跑 `AgentTempStorageMigrationTests.swift`（`.serialized`，注入 `legacyDefaultsDomainProvider` / `legacyFallbackRootDirectoryProvider`）。

> **#811 变异验证**（`AgentTempStorageMigrationTests`）：把 `migrateData` 中「无版本旧目录」的 `if` 合并块改回 `guard fileExists else { return }`（复现原 bug，导入被短路）→ `importsRetentionDaysWhenOnlyVersionedDirectoryExists`（14→7）与 `importsRetentionDaysWhenNoLegacyDirectoryExists`（30→7）RED；`mergesUnversionedDirectoryAndStillImports`（无版本目录存在）仍 GREEN。该变异锁定「配置导入不得被文件目录守卫短路」的迁移不变量。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentTempStorageRuntimeBridge | 注入目录后 resolvedPluginDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `injectedDirectoryResolvesToInjectedDirectory` |
| 2 | AgentTempStorageRuntimeBridge | 注入目录后共享存储与本地存储都落在该目录下 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sharedStorageUsesInjectedDirectory` |
| 3 | AgentTempStorageRuntimeBridge | 未注入目录时守卫拒绝回退到真实数据目录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refusesFallbackWithoutInjection` |
| 4 | 综合 | pluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 5 | 综合 | pluginRegistersThreeTools | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersThreeTools` |
| 6 | 综合 | toolsAreLowRisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolsAreLowRisk` |
| 7 | 综合 | localizationCatalogIsPackaged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizationCatalogIsPackaged` |
| 8 | 综合 | storageSupportsNestedReadWriteAndList（嵌套写入后列表递归可见） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `storageSupportsNestedReadWriteAndList` |
| 9 | 综合 | storageRejectsInvalidAndTraversingPaths | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `storageRejectsInvalidAndTraversingPaths` |
| 10 | 综合 | readReportsMissingFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readReportsMissingFile` |
| 11 | 综合 | listFilesSortsByRecencyAndExcludesDirectories | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listFilesSortsByRecencyAndExcludesDirectories` |
| 12 | 综合 | purgeRemovesOnlyFilesOlderThanRetention | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `purgeRemovesOnlyFilesOlderThanRetention` |
| 13 | 综合 | storageErrorsExposeDescriptions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storageErrorsExposeDescriptions` |
| 14 | 综合 | preservesLeadingAndTrailingSpacesInFilenames（首尾空格不得被裁剪，避免不同名称互相覆盖） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `preservesLeadingAndTrailingSpacesInFilenames` |
| 15 | 综合 | 配置不可读时中止清理并保留文件，同时暴露配置错误（**回归 #973**） | 已保存 14 天策略后损坏 settings.plist，存在 8 天前的文件 | 调用 `read` 触发清理 | 抛出 `settingsUnavailable`，8 天文件仍在；删除配置后才回退默认 7 天 | P1 | ✅ 已覆盖 | `unreadableSettingsAbortPurgeAndSurfaceError` |
| 16 | 综合 | 过期文件删除失败时读取不得返回过期内容（**回归 #974**） | 顶层文件修改时间早于保留期，父目录置为 0o555 使删除失败但文件仍可读 | 调用 `read` 触发清理 | 抛出 `purgeFailed` 且详情包含文件名，过期文件仍存在于磁盘但不再被当作正常结果返回 | P1 | ✅ 已覆盖 | `readFailsWhenExpiredFileCannotBeDeleted` |
| 17 | 综合 | 过期嵌套文件必须被递归清理（**回归 #200**） | 写入 `exports/data.json` 并把修改时间设为 40 天前 | 调用 `purgeExpiredFiles` 后 read/list | read 抛出 `fileNotFound`，列表为空 | P0 | ✅ 已覆盖 | `purgeRemovesExpiredNestedFiles` |
| 18 | 综合 | 递归清理只删过期文件，保留新鲜嵌套与顶层文件（**回归 #200**） | 嵌套旧文件 + 嵌套新文件 + 顶层新文件 | 调用 `purgeExpiredFiles` 后 list/read | 仅剩 `fresh.md` 与 `logs/fresh.log`，新嵌套文件内容可读 | P1 | ✅ 已覆盖 | `purgeKeepsFreshNestedFilesWhileRemovingExpiredOnes` |
| 19 | TempFileStorageSymlink | 写入必须拒绝指向存储外的文件符号链接（**回归 #232**） | 存储内 `link.md` 链接到外部 `target.md`（内容 original） | 调用 `write(filename: "link.md")` | 抛出 `pathTraversal`，外部文件内容保持 original | P0 | ✅ 已覆盖 | `writeRejectsFileSymlinkPointingOutsideStorage` |
| 20 | TempFileStorageSymlink | 读取不得经指向存储外的文件符号链接越界（**回归 #232**） | 存储内 `link.md` 链接到外部 `secret.md` | 调用 `read(filename: "link.md")` | 抛出 `pathTraversal`，外部内容不被返回 | P0 | ✅ 已覆盖 | `readRejectsFileSymlinkPointingOutsideStorage` |
| 21 | TempFileStorageSymlink | 写入不得经符号链接目录越界创建外部文件（**回归 #232**） | 存储内 `exports` 目录链接指向外部目录，叶子 `data.json` 尚不存在 | 调用 `write(filename: "exports/data.json")` | 抛出 `pathTraversal`，外部目录不出现 `data.json` | P0 | ✅ 已覆盖 | `writeRejectsNestedPathThroughSymlinkDirectory` |
| 22 | TempFileStorageSymlink | 读取经符号链接目录的嵌套路径被拒绝（**回归 #232**） | 存储内 `exports` 链接指向含 `secret.txt` 的外部目录 | 调用 `read(filename: "exports/secret.txt")` | 抛出 `pathTraversal` | P1 | ✅ 已覆盖 | `readRejectsNestedPathThroughSymlinkDirectory` |
| 23 | TempFileStorageSymlink | 指向存储内部的符号链接保持可用（**回归 #232**） | 写入 `real.md` 后创建内部链接 `alias.md` | 调用 `read(filename: "alias.md")` | 返回 real.md 内容，内部链接不被误杀 | P1 | ✅ 已覆盖 | `symlinksStayingInsideStorageRemainUsable` |
| 24 | TempFileStorageSymlink | 经悬空符号链接目录写入失败且不产生外部副作用（**回归 #232**） | `exports` 链接指向尚不存在的外部目录 | 调用 `write(filename: "exports/data.json")` | 写入抛出错误，外部目录保持为空 | P1 | ✅ 已覆盖 | `writeThroughDanglingSymlinkDirectoryFailsWithoutExternalSideEffects` |
| 25 | 综合 | 根级点文件可写可读且列表可见（**回归 #327**） | 写入 `.audit.txt`（新鲜） | 调用 `read` 与 `listFiles` | read 返回内容，列表为 `[".audit.txt"]`，不因隐藏文件选项而消失 | P0 | ✅ 已覆盖 | `listsAndReadsRootDotfile` |
| 26 | 综合 | 过期根级点文件必须被清理删除（**回归 #327**） | 写入 `.audit-old.txt` 并把修改时间设为 40 天前 | 调用 `purgeExpiredFiles` 后 read/list | read 抛出 `fileNotFound`，列表为空，点文件不再永久残留 | P0 | ✅ 已覆盖 | `purgeRemovesExpiredRootDotfile` |
| 27 | 综合 | 存储目录打不开时 listFiles 必须抛错而非返回空列表（**回归 #511**） | 写入 report.md 后用普通文件替换存储目录（ENOTDIR，与 uid 无关） | 调用 `listFiles` | 抛出 `listFailed`，不得把枚举失败当成空目录 | P0 | ✅ 已覆盖 | `listFilesThrowsWhenDirectoryCannotBeEnumerated` |
| 28 | 综合 | 可读空目录必须返回空列表而非抛错（**回归 #511**） | 新建可读的空存储目录 | 调用 `listFiles` | 返回空列表，与「目录打不开」严格区分 | P0 | ✅ 已覆盖 | `listFilesReturnsEmptyForReadableEmptyDirectory` |
| 29 | 数据迁移 | 仅有版本目录升级时仍导入旧保留天数（**回归 #811**） | 版本旧目录含文件、无版本旧目录不存在，旧 UserDefaults 保留天数=14 | 注入假域与 fallback 根后调用 `migrateData` | settings.plist 保留天数=14（非默认 7），版本目录文件被迁移 | P0 | ✅ 已覆盖 | `importsRetentionDaysWhenOnlyVersionedDirectoryExists` |
| 30 | 数据迁移 | 没有任何旧目录时仍导入旧保留天数（**回归 #811**） | 无版本/无版本旧目录均不存在，旧保留天数=30 | 注入假域与 fallback 根后调用 `migrateData` | settings.plist 保留天数=30 | P0 | ✅ 已覆盖 | `importsRetentionDaysWhenNoLegacyDirectoryExists` |
| 31 | 数据迁移 | 插件存储已有配置时不被旧值覆盖 | 先写入保留天数=21，旧 UserDefaults=14 | 调用 `migrateData` | 保留天数仍为 21 | P1 | ✅ 已覆盖 | `doesNotOverwriteExistingSettings` |
| 32 | 数据迁移 | 没有旧保留天数时不导入，保持默认 | 旧域为空 | 调用 `migrateData` | 不生成 settings.plist，解析保留天数为默认 7 | P1 | ✅ 已覆盖 | `skipsImportWhenNoLegacyValue` |
| 33 | 数据迁移 | 无版本旧目录存在时合并其内容并仍导入保留天数 | 无版本旧目录含文件，旧保留天数=14 | 注入假域与 fallback 根后调用 `migrateData` | 旧文件被合并进插件目录，且保留天数=14 | P1 | ✅ 已覆盖 | `mergesUnversionedDirectoryAndStillImports` |

> 说明：全部 **33 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 14 / 14
- P1: 已覆盖 18 / 18
- P2: 已覆盖 1 / 1
- **合计: 33 / 33**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（14 条）
- **P1**: 其余功能性用例（18 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 33 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAgentTempStorage
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
