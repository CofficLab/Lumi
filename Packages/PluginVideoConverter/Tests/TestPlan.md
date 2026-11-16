# TestPlan — PluginVideoConverter

## 包概述

PluginVideoConverter 的实现包，包含 12 个主要类型；当前测试覆盖 21 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 21

核心组件（源码目录）:
- `Models/`
- `Services/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `VideoConverterLocalization`
- `VideoConverterPlugin`
- `VideoConverterViewModel`
- `VideoFileItem`
- `VideoFormat`
- `VideoConverterService`
- `ConversionLogView`
- `ConversionSettingsView`
- `DropZoneView`
- `VideoConverterAboutView`
- `VideoConverterMainView`
- `VideoConverterManualView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **VideoConverterLocalization**（3 条）：由 `pluginBundleIncludesLocalizedStringsCatalog`、`stringCatalogDefinesRequiredLanguages`、`stringCatalogIncludesLocalizedDisplayStrings` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VideoConverterPlugin**（8 条）：由 `onBootRegistersEntryContentViewAndDocs`、`onBootAppendsToExistingItems`、`onBootNoOpsWithoutProviders` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VideoConverterOutputURL**（5 条）：由 `sameFormatMP4ProducesDistinctOutput`、`outputNeverEqualsInputForAnyFormat` 等用例锁定；输出 URL 永远不得等于输入（同格式转换须加后缀），否则 FFmpeg 拒绝读写同一文件（#378）。
- **VideoConverterService**（5 条）：由 `conversionWithLargeStderrCompletes`、`cancelDuringConversionStopsPromptly`、`cancelDuringProbeStopsPromptly` 等用例锁定；stderr 必须与进程退出并发排空（先 wait 后读会在管道写满时永久死锁），进程退出必须异步等待（actor 内同步 `waitUntilExit` 会让 `cancel()` 永远排不进来），时长探测只读容器元数据、不做全量解码，探测与转换进程都必须可被 cancel 终止（#209）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | VideoConverterLocalization | plugin bundle includes localized strings catalog | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginBundleIncludesLocalizedStringsCatalog` |
| 2 | VideoConverterLocalization | string catalog defines required languages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stringCatalogDefinesRequiredLanguages` |
| 3 | VideoConverterLocalization | string catalog includes localized display strings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stringCatalogIncludesLocalizedDisplayStrings` |
| 4 | VideoConverterPlugin | onBoot 注册 ActivityBar 入口、主内容与文档 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersEntryContentViewAndDocs` |
| 5 | VideoConverterPlugin | onBoot 追加语义不覆盖已有入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootAppendsToExistingItems` |
| 6 | VideoConverterPlugin | Provider 未注册时 onBoot 优雅降级 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootNoOpsWithoutProviders` |
| 7 | VideoConverterPlugin | 插件可经 kernel.start 启动并注册贡献 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startViaKernelBootsPlugin` |
| 8 | VideoConverterPlugin | onShutdown 撤回 ActivityBar 入口、主内容与文档贡献 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onShutdownWithdrawsContributions` |
| 9 | VideoConverterPlugin | VideoConverterMainView 可渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mainViewRenders` |
| 10 | VideoConverterPlugin | VideoConverterAboutView 可渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `aboutViewRenders` |
| 11 | VideoConverterPlugin | VideoConverterManualView 可渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `manualViewRenders` |
| 12 | VideoConverterOutputURL | 同格式 MP4 转换产出独立输出文件，不写回输入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `sameFormatMP4ProducesDistinctOutput` |
| 13 | VideoConverterOutputURL | 不同格式转换保留原文件名仅换扩展名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentFormatKeepsBaseName` |
| 14 | VideoConverterOutputURL | 大小写不同的同格式扩展名也不写回输入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `caseInsensitiveSameExtensionAvoidsInput` |
| 15 | VideoConverterOutputURL | 任意格式的输出都不等于输入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `outputNeverEqualsInputForAnyFormat` |
| 16 | VideoConverterOutputURL | 输入名已含后缀时仍产出不同于输入的文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suffixedInputStillProducesDistinctOutput` |
| 17 | VideoConverterService | 转换输出超过管道缓冲的 stderr 仍能完成（死锁回归 #209） | shell 替身转换分支输出 ~380KB stderr | 执行 `convert` | 正常完成且进度到 1.0，不死锁 | P0 | ✅ 已覆盖 | `conversionWithLargeStderrCompletes` |
| 18 | VideoConverterService | 转换进行中 cancel 能立刻终止进程（#209） | 替身转换分支 sleep 30 | 启动转换后 `cancel()` | 抛 `CancellationError` 且耗时 < 5s | P0 | ✅ 已覆盖 | `cancelDuringConversionStopsPromptly` |
| 19 | VideoConverterService | 探测进行中 cancel 能终止探测且不进入转换（#209） | 替身探测分支 sleep 30，转换分支写标记文件 | 探测期间 `cancel()` | 抛 `CancellationError`、耗时 < 5s、标记文件不存在 | P0 | ✅ 已覆盖 | `cancelDuringProbeStopsPromptly` |
| 20 | VideoConverterService | 时长按元数据探测，不做全量解码（#209） | 替身按 `-f null` 与否返回不同 Duration | 执行 `convert` | 进度含 50%（150.5s 元数据时长），而非全量解码分支的 0 | P1 | ✅ 已覆盖 | `probeReadsMetadataWithoutFullDecode` |
| 21 | VideoConverterService | 转换进程非零退出仍抛出 conversionFailed | 替身转换分支 exit 3 | 执行 `convert` | 抛 `conversionFailed(exitCode: 3)` | P1 | ✅ 已覆盖 | `failedConversionThrows` |

> 说明：全部 **21 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（#209）：三组变异各自只打红对应用例——
> ① 探测参数改回 `-f null -` 全量解码 → 用例 20 红（进度拿不到 50%）；
> ② `runAndWaitForExit` 改回 actor 内同步 `waitUntilExit` → 用例 18/19 红
> （cancel 排不进 actor，耗时 30s 超过 5s 上限）；
> ③ 转换改回「先 wait 后读」→ 用例 17 红（管道写满互相等待，
> 12s 自杀闹钟 SIGTERM 后以 conversionFailed(15) 告终）。恢复修复后全部转绿。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 15 / 15
- P2: 已覆盖 0 / 0
- **合计: 21 / 21**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（15 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 21 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginVideoConverter
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
