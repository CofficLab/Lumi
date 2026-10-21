# TestPlan — PluginDevice

## 包概述

PluginDevice Lumi 的设备信息插件，提供系统资源监控（CPU / 内存 / GPU / 电池 / 存储）与历史趋势， 支持主内容视图、菜单栏图表、设置页与文档页等贡献点。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 17

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

> 说明：全部 **17 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 12 / 12
- P2: 已覆盖 5 / 5
- **合计: 17 / 17**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（12 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 17 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
