# TestPlan — PluginDockerManager

## 包概述

DockerManagerPlugin Docker container management plugin for Lumi.

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 58

核心组件（源码目录）:
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DockerManagerPluginSupport`
- `DockerError`
- `DockerKit`
- `DockerManagerServicing`
- `DockerImagesView`
- `DockerManagerAboutView`
- `DockerManagerManualView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DockerManagerLogic**（37 条）：由 `parsesDecimalUnits`、`parsesBinaryUnits`、`parsesFractionalAndSpacedValues` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DockerManagerPluginLifecycle**（9 条）：由 `registerAddsDocsEntries`、`registerWithoutDocsProviderIsNoop`、`bootRegistersActivityBarItem` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（5 条）：由 `pluginMetadataIsStable`、`v2IdentifiersRemainStable`、`selectingAnotherImageIgnoresStaleDetails` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DockerManagerLogic | 十进制单位换算正确 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesDecimalUnits` |
| 2 | DockerManagerLogic | 二进制单位换算正确 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesBinaryUnits` |
| 3 | DockerManagerLogic | 小数与空白被正确处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesFractionalAndSpacedValues` |
| 4 | DockerManagerLogic | 无法识别的体积返回 0 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsUnparsableSizes` |
| 5 | DockerManagerLogic | 名称在仓库缺失时回退到短 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nameFallsBackToShortID` |
| 6 | DockerManagerLogic | 短 ID 去掉 sha256 前缀并截断到 12 位 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `shortIDTruncates` |
| 7 | DockerManagerLogic | 镜像可编解码且缺省 digest 视为空串 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageRoundTripsThroughCodable` |
| 8 | DockerManagerLogic | 缺少 Digest 字段时解码得到空串 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesImageWithoutDigest` |
| 9 | DockerManagerLogic | 历史记录的 Size 为数字时转成可读字符串 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesHistoryWithNumericSize` |
| 10 | DockerManagerLogic | 历史记录的 Size 为字符串时原样保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesHistoryWithStringSize` |
| 11 | DockerManagerLogic | 错误描述覆盖三种情况 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptionsAreInformative` |
| 12 | DockerManagerLogic | 合法引用通过校验 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsValidReferences` |
| 13 | DockerManagerLogic | 首尾空白被裁剪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trimsWhitespace` |
| 14 | DockerManagerLogic | 空引用被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyReference` |
| 15 | DockerManagerLogic | 超长引用被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsOverlongReference` |
| 16 | DockerManagerLogic | 以连字符开头的引用被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsLeadingDash` |
| 17 | DockerManagerLogic | 含非法字符的引用被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsIllegalCharacters` |
| 18 | DockerManagerLogic | 含空路径段的引用被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyPathSegment` |
| 19 | DockerManagerLogic | 刷新成功后填充镜像列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshFillsImages` |
| 20 | DockerManagerLogic | 刷新失败时记录错误信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshReportsError` |
| 21 | DockerManagerLogic | 删除镜像后从列表移除并清空选中详情 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteRemovesImage` |
| 22 | DockerManagerLogic | 删除失败时记录错误信息并保留列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteReportsError` |
| 23 | DockerManagerLogic | 搜索按仓库、标签与 ID 过滤 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchFiltersImages` |
| 24 | DockerManagerLogic | 按名称排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sortsByName` |
| 25 | DockerManagerLogic | 切换排序项立即按新选项重新排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sortOptionChangeAppliesToNewOption` |
| 26 | DockerManagerLogic | 按体积排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sortsBySize` |
| 27 | DockerManagerLogic | 按创建时间排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sortsByCreated` |
| 28 | DockerManagerLogic | 扫描成功时写入扫描结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scanStoresResult` |
| 29 | DockerManagerLogic | 扫描失败时写入失败原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scanReportsFailure` |
| 30 | DockerManagerLogic | 导出失败时记录错误信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportReportsFailure` |
| 31 | DockerManagerLogic | 加载失败时记录错误信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadReportsFailure` |
| 32 | DockerManagerLogic | 标签失败时返回 false 并记录错误信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tagReportsFailure` |
| 33 | DockerManagerLogic | 拉取成功后刷新列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pullRefreshesImages` |
| 34 | DockerManagerLogic | 文件面板取消错误被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresUserCancelledError` |
| 35 | DockerManagerLogic | 其它文件面板错误被记录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsOtherFilePanelError` |
| 36 | DockerManagerPluginLifecycle | 注册时写入关于与说明书文档条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerAddsDocsEntries` |
| 37 | DockerManagerPluginLifecycle | 缺少文档 Provider 时注册不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerWithoutDocsProviderIsNoop` |
| 38 | DockerManagerPluginLifecycle | 启动后注册活动栏入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootRegistersActivityBarItem` |
| 39 | DockerManagerPluginLifecycle | 缺少活动栏 Provider 时启动不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutActivityBarProviderIsNoop` |
| 40 | DockerManagerPluginLifecycle | 启动后入口被自动激活并切换内容区、工具栏与根视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootActivatesEntryAndSwitchesChrome` |
| 41 | DockerManagerPluginLifecycle | 停用入口时恢复工具栏分类与根视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deactivationRestoresChrome` |
| 42 | DockerManagerPluginLifecycle | 重新激活入口时再次切换内容区 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reactivationSwitchesContentAgain` |
| 43 | DockerManagerPluginLifecycle | 关闭插件时移除活动栏入口与工具栏项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesActivityBarAndToolbarItems` |
| 44 | DockerManagerPluginLifecycle | 注销时移除文档条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unregisterRemovesDocsEntries` |
| 45 | 综合 | pluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 46 | 综合 | v2IdentifiersRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `v2IdentifiersRemainStable` |
| 47 | 综合 | selectingAnotherImageIgnoresStaleDetails | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectingAnotherImageIgnoresStaleDetails` |
| 48 | 综合 | pullImageRejectsInvalidReferencesBeforeCallingDocker | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pullImageRejectsInvalidReferencesBeforeCallingDocker` |
| 49 | 综合 | tagImageRejectsInvalidReferencesBeforeCallingDocker | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tagImageRejectsInvalidReferencesBeforeCallingDocker` |
| 50 | Docker image decoding | 缺少 VirtualSize 时回退到 Size，而不是丢弃整行 | Docker 29.x 风格输出，无 VirtualSize | 解码该行 | `virtualSize == size`，镜像被保留 | P1 | ✅ 已覆盖 | `missingVirtualSizeFallsBackToSize` |
| 51 | Docker image decoding | 全部行解析失败时抛错，而不是返回成功的空列表 | 只有无效 JSON 行 | 调用 `decodeImages` | 抛出 `DockerError.parsingFailed` | P0 | ✅ 已覆盖 | `allInvalidLinesThrow` |
| 52 | Docker image decoding | 部分行解析失败时保留成功行 | 一行有效 + 一行无效 | 调用 `decodeImages` | 返回有效镜像，不抛错 | P1 | ✅ 已覆盖 | `partialFailureKeepsValidImages` |
| 53 | Docker image decoding | 空输出返回空列表 | 空字符串 | 调用 `decodeImages` | 返回空数组 | P2 | ✅ 已覆盖 | `emptyOutputReturnsEmptyList` |
| 54 | 综合 | 导出失败时保留目标路径上的原文件并清理临时文件 | 目标文件已存在，docker save 写了一半后失败 | 调用 `exportImage` | 返回 false，原文件内容不变，目录中无临时文件 | P0 | ✅ 已覆盖 | `failedExportKeepsExistingDestinationAndCleansTemporaryFile` |
| 55 | 综合 | 导出成功时原子替换已有目标文件 | 目标文件已存在，docker save 成功 | 调用 `exportImage` | 返回 true，目标内容为新导出内容，目录中无临时文件 | P1 | ✅ 已覆盖 | `successfulExportAtomicallyReplacesExistingDestination` |
| 56 | 综合 | docker save 未产出文件时报告失败且不留下文件 | 服务成功返回但未写文件 | 调用 `exportImage` | 返回 false，错误信息含 no output file，目录为空 | P1 | ✅ 已覆盖 | `exportWithoutOutputFileReportsFailureAndRemovesNothingElse` |
| 57 | DockerManagerLogic | 扫描期间切换镜像后，旧扫描结果不再写入详情页 | 镜像 A 扫描延迟 300ms，期间选中镜像 B | 扫描 A → 切到 B → 等 A 返回 | `selectedImage` 仍为 B，`scanResult` 保持 nil，`isLoading` 为 false | P0 | ✅ 已覆盖 | `staleScanResultIsIgnoredAfterImageSwitch` |
| 58 | DockerManagerLogic | 重叠操作期间转圈保持到最后一个操作结束 | 扫描耗时 400ms | 扫描进行中再刷新镜像列表 | 刷新结束时 `isLoading` 仍为 true，扫描结束后才变 false | P1 | ✅ 已覆盖 | `overlappingOperationsKeepLoadingUntilLastCompletes` |

> 说明：全部 **58 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 12 / 12
- P1: 已覆盖 43 / 43
- P2: 已覆盖 3 / 3
- **合计: 58 / 58**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（12 条）
- **P1**: 其余功能性用例（43 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 58 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDockerManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
