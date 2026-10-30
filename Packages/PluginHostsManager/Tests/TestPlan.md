# TestPlan — PluginHostsManager

## 包概述

PluginHostsManager 的实现包，包含 7 个主要类型；当前测试覆盖 16 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 16

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

- **HostsFileService**（2 条）：由 `readsAndBacksUpHostsFile`、`reportsMissingHostsFile` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HostsManagerFileFlow**（2 条）：由 `loadsAndSavesThroughInjectedFileOperations`、`reportsFileOperationFailures` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HostsManagerViewModel**（3 条）：由 `filtersByGroupAndSearch`、`rejectsInvalidEntry`、`mutatesEntriesAndPersists` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HostsParser**（6 条）：由 `parsesActiveEntries`、`parsesCommentsAndGroups`、`preservesBlankLines` 等用例锁定；改动该模块时优先跑对应测试文件。
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

> 说明：全部 **16 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 12 / 12
- P2: 已覆盖 2 / 2
- **合计: 16 / 16**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（12 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 16 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
