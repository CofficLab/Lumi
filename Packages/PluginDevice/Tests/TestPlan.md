# TestPlan — PluginDevice

## 包概述

PluginDevice Lumi 的设备信息插件，提供系统资源监控（CPU / 内存 / GPU / 电池 / 存储）与历史趋势， 支持主内容视图、菜单栏图表、设置页与文档页等贡献点。

平台: macOS 14+, iOS 17+
测试文件: 12 个，用例总数: 45

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DevicePlugin`
- `BatteryPowerSource`
- `CPUTimeRange`
- `DeviceData`
- `DeviceHistoryRange`
- `DeviceHistorySample`
- `GPUTimeRange`
- `MemoryTimeRange`
- `SystemMetrics`
- `VolumeInfo`
- `DeviceMetricsObserver`
- `MenuBarAppearanceObserver`
- `BatteryHistoryService`
- `BatteryService`
- `CPUHistoryService`
- `CPUService`
- `ThermalHistoryService`
- `ThermalDataPoint`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（9 条）：由 `onBootRegistersEntryContentViewAndDocs`、`onBootAppendsToExistingEntries`、`onBootNoOpsWithoutSettingView` 等用例锁定；改动该模块时优先跑对应测试文件。
- **温度历史**（3 条）：由 `recordsRecentPoints`、`filtersRecentByRange`、`usesLongTermBufferForLongerRanges` 等用例锁定；改动温度历史采集或时间范围语义时优先跑对应测试文件。
- **温度传感器**（5 条）：由 `privateSymbolsAvailable`、`sortedByIndex`、`readingsInRange` 等用例锁定；改动底层传感器读取时优先跑对应测试文件。
- **历史范围裁剪**（4 条）：由 `oneHourRangeUsesHighResolutionBuffer`、`fourHourRangeTrimsLongTermBuffer` 等用例锁定；改动历史时间范围语义或视图取数方式时优先跑对应测试文件。
- **历史图表几何**（4 条）：由 `xMapsTimestampsProportionally`、`longGapKeepsProportionalWidth`、`xClampsOutOfRangeTimestamps`、`hoverSelectsNearestTimestamp` 锁定，防止绘线或悬浮选点退回数组等距映射。
- **CPU 采样**（4 条）：由 `averageUsageAcrossCPUs`、`usageIsDeltaBased`、`shortBuffersReturnZero`、`zeroCPUCountReturnsZero` 锁定，防止 `host_processor_info` 返回的 CPU 数量/buffer 长度与循环不一致时越界。
- **本地化**（5 条）：由 `memoryMonitorHasTranslationsInCompiledBundle`、`sensorLabelUsesInjectedLocalization`、`sensorLabelHasTranslationsInCompiledBundle`、`registrationTitlesUseInjectedLocalization`、`entryLabelsHaveTranslationsInCompiledBundle` 锁定，防止视图词条与注册入口标题绕过 `pluginLocalization`，或在某个规范语言下缺失而回退成英文 key。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | onBoot 不再注册内存监控设置入口，但仍注册主内容与文档 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersEntryContentViewAndDocs` |
| 2 | 综合 | onBoot 追加语义不覆盖已有入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootAppendsToExistingEntries` |
| 3 | 综合 | 设置视图未注册时 onBoot 优雅降级 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootNoOpsWithoutSettingView` |
| 4 | 综合 | 插件可经 kernel.start 启动并注册入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startViaKernelBootsPlugin` |
| 5 | 综合 | ActivityBar 激活设备入口时切换主内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityBarActivationSetsContentView` |
| 6 | 综合 | DeviceData 采集静态系统信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deviceDataStaticInfo` |
| 7 | 综合 | DeviceData 动态指标可刷新且非负 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deviceDataDynamicMetrics` |
| 8 | 综合 | DeviceInfoAboutView 可渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `aboutViewRenders` |
| 9 | 综合 | DeviceInfoManualView 可渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `manualViewRenders` |
| 10 | 温度历史 | 温度采样点写入高频缓冲 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recordsRecentPoints` |
| 11 | 温度历史 | 1 小时范围只保留截止时间之后的点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filtersRecentByRange` |
| 12 | 温度历史 | 超过 1 小时的范围走分钟级聚合缓冲 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesLongTermBufferForLongerRanges` |
| 13 | 温度传感器 | 私有 HID 符号仍可解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `privateSymbolsAvailable` |
| 14 | 温度传感器 | 读数按传感器下标升序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sortedByIndex` |
| 15 | 温度传感器 | 读数处于物理合理区间 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `readingsInRange` |
| 16 | 温度传感器 | 峰值等于同批次最大值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `peakIsMaximum` |
| 17 | 温度传感器 | 可用性与非空读数一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `availabilityMatchesRead` |
| 18 | 历史范围裁剪 | 1 小时范围取高频缓冲并截断过期样本 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oneHourRangeUsesHighResolutionBuffer` |
| 19 | 历史范围裁剪 | 4 小时范围截断超出范围的长期样本 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fourHourRangeTrimsLongTermBuffer` |
| 20 | 历史范围裁剪 | 24 小时与 30 天范围返回不同的数据量 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `differentLongRangesReturnDifferentData` |
| 21 | 历史范围裁剪 | 内存历史同样按范围截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `memoryHistoryTrimsByRange` |
| 22 | CPU 进程监控 | Apple Silicon 24MHz ticks 下占满单核为 100% | 注入 timebase 125/3 | 计算 CPU 百分比 | 结果为 100 | P1 | ✅ 已覆盖 | `appleSiliconTimebaseYieldsOneHundredPercent` |
| 23 | CPU 进程监控 | Intel 1GHz ticks 下占满单核为 100% | 注入 timebase 1/1 | 计算 CPU 百分比 | 结果为 100 | P1 | ✅ 已覆盖 | `intelTimebaseYieldsOneHundredPercent` |
| 24 | CPU 进程监控 | 多线程进程可以超过 100% | 注入 timebase 125/3，1 秒内 2 核 ticks | 计算 CPU 百分比 | 结果为 200 | P1 | ✅ 已覆盖 | `multiCoreUsageExceedsOneHundredPercent` |
| 25 | CPU 进程监控 | 零采样间隔返回 0 | 注入 elapsed=0 | 计算 CPU 百分比 | 结果为 0 | P2 | ✅ 已覆盖 | `zeroElapsedReturnsZero` |
| 26 | 综合 | 禁用自动撤回，重新启用恢复菜单栏贡献 | 真实 kernel 启停插件 | 禁用/启用插件 | 禁用后贡献为空，启用后恢复 CPU 与内存弹窗贡献 | P1 | ✅ 已覆盖 | `disableAndEnableRestoresMenuBarContributions` |
| 27 | CPU 进程监控 | 直接展示真实 CPU 占用，不按前 N 名归一化 | 构造 0.6% / 12.4% / 120% 的进程指标 | 读取展示文案 | 分别显示 1% / 12% / 120% | P1 | ✅ 已覆盖 | `displaysRealCPUUsageWithoutNormalization` |
| 28 | CPU 进程监控 | 进度条以单核 100% 为满格且不超过 100% | 构造 50% / 120% / -5% 的进程指标 | 读取进度条比例 | 分别得到 0.5 / 1 / 0 | P2 | ✅ 已覆盖 | `barFractionIsCappedAtOneHundredPercent` |
| 29 | CPU 进程监控 | 同名多进程合并为一条并标注份数，本应用组单独标记 | 2 个同名 Chrome Helper + PID 为自身的 Lumi | 执行聚合 | Chrome 一条且份数 2、CPU 相加；Lumi 标记为本应用 | P1 | ✅ 已覆盖 | `aggregatesSameNameProcessesAndMarksSelf` |
| 30 | CPU 进程监控 | 不同完整名称的进程不会被误合并 | WebKit WebContent / Networking 两条采样 | 执行聚合 | 保持两条独立记录，份数均为 1 | P1 | ✅ 已覆盖 | `keepsDistinctNamesSeparate` |
| 31 | CPU 进程监控 | 主弹窗只展示前 5 条，完整列表保留 | 7 条进程指标 | 读取预览与完整列表 | 预览 5 条，完整列表 7 条 | P2 | ✅ 已覆盖 | `previewLimitsToFive` |
| 32 | CPU 进程监控 | CPU 采样间隔与网络区块统一为 1 秒 | 读取采样间隔常量 | 断言常量 | 等于 1.0 | P1 | ✅ 已覆盖 | `samplingIntervalMatchesNetworkBlock` |
| 33 | 历史图表几何 | X 坐标按时间戳比例映射 | 时间戳 0 / 3600 / 7200，宽 200 | 调用 `DeviceHistoryChartGeometry.x` | 分别为 0 / 100 / 200 | P1 | ✅ 已覆盖 | `xMapsTimestampsProportionally` |
| 34 | 历史图表几何 | 长时间空洞占据真实水平距离 | 时间戳 0 / 60 / 3660，宽 100 | 计算 60s 的 X 坐标 | 约 1.639，而非等距的 50 | P1 | ✅ 已覆盖 | `longGapKeepsProportionalWidth` |
| 35 | 历史图表几何 | 超出时间范围的值被钳制在边界 | 时间范围 0...100，宽 50 | 传入 -10 / 200 / 起止相同 | 分别为 0 / 50 / 0 | P1 | ✅ 已覆盖 | `xClampsOutOfRangeTimestamps` |
| 36 | 历史图表几何 | 悬浮选点按时间轴就近命中 | 时间戳 0 / 60 / 3660，宽 100 | 传入 x=1.639 / 50 / 99 / 0 / 空数组 | 命中下标 1 / 1 / 2 / 0 / nil | P1 | ✅ 已覆盖 | `hoverSelectsNearestTimestamp` |
| 37 | CPU 采样 | 两个 CPU 各半负载时返回平均使用率 | 2 个 CPU 的完整状态数组 | 调用 `cpuUsage` | 返回 0.5 | P1 | ✅ 已覆盖 | `averageUsageAcrossCPUs` |
| 38 | CPU 采样 | 差分基于历史采样而不是绝对值 | 当前/历史状态均非零 | 调用 `cpuUsage` | 按两次采样的增量返回 0.35 | P1 | ✅ 已覆盖 | `usageIsDeltaBased` |
| 39 | CPU 采样 | buffer 长度不足 CPU 数量所需时返回 0 且不越界 | 数组长度小于 `cpuCount * CPU_STATE_MAX` | 以更大的 CPU 数量/长度调用 | 返回 0，不读取越界内存 | P0 | ✅ 已覆盖 | `shortBuffersReturnZero` |
| 40 | CPU 采样 | CPU 数量为 0 时返回 0 | `cpuCount = 0` | 调用 `cpuUsage` | 返回 0 | P2 | ✅ 已覆盖 | `zeroCPUCountReturnsZero` |
| 41 | 本地化 | Memory Monitor 在 en / zh-Hans / zh-Hant / zh-HK / zh-TW 下均有译文 | 编译后的资源包 | 读取各语言 `Localizable.strings` | 五种语言都返回对应译文，不回退成英文 key（**回归** #902） | P1 | ✅ 已覆盖 | `memoryMonitorHasTranslationsInCompiledBundle` |
| 42 | 本地化 | 传感器行标签经注入的本地化解析并保留下标 | 注入 marker 解析器 | 调用 `ThermalSensorLabel.text(index: 3, resolve:)` | 得到 `localized:Sensor 3`，证明不再写死英文字面量（**回归** #901） | P1 | ✅ 已覆盖 | `sensorLabelUsesInjectedLocalization` |
| 43 | 本地化 | Sensor %d 在编译产物中已有译文 | 编译后的资源包 | 读取 en / zh-Hans / zh-HK / zh-TW 的 `Localizable.strings` | 各语言都返回对应译文（**回归** #901） | P1 | ✅ 已覆盖 | `sensorLabelHasTranslationsInCompiledBundle` |
| 44 | 本地化 | 文档、活动栏与菜单标题经过本地化解析 | 注入 marker 解析器，真实 kernel 启动并启用插件 | 读取文档入口、ActivityBar 入口与菜单栏贡献标题 | 全部为 `localized:Device Info` / `localized:Memory`，证明注册链不再写死中文字面量（**回归** #900） | P1 | ✅ 已覆盖 | `registrationTitlesUseInjectedLocalization` |
| 45 | 本地化 | Device Info 与 Memory 词条在所有规范语言下都有译文 | 编译后的资源包 | 读取 en / zh-Hans / zh-Hant / zh-HK / zh-TW 的 `Localizable.strings` | 五种语言都有对应译文，不回退成英文 key（**回归** #900） | P1 | ✅ 已覆盖 | `entryLabelsHaveTranslationsInCompiledBundle` |

> 说明：全部 **45 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 31 / 31
- P2: 已覆盖 9 / 9
- **合计: 45 / 45**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（31 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（9 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 45 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDevice
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
