# TestPlan — PluginPortManager

## 包概述

PortManagerPlugin View and manage port usage

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 20

核心组件（源码目录）:
- `Services/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PortManagerPlugin`
- `PortManagerView`
- `PortInfo`
- `PortManagerAboutView`
- `PortManagerManualView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（10 条）：由 `v2PluginMetadataIsStable`、`parsesLsofListeningPorts`、`scanThrowsOnSignalTerminationWithEmptyStderr` 等用例锁定；lsof 扫描只有退出码 1 且 stderr 为空才是合法无端口，信号终止或其他非零退出必须抛 scanFailed（**回归 #523**）；改动该模块时优先跑对应测试文件。
- **输出截断**（#258，3 条）：由 `scanThrowsWhenOutputTruncated`、`scanReturnsPortsWhenOutputComplete`、`scanThrowsOnSignalExitThroughSeam` 锁定；lsof 输出被 KitShell 截断（stdoutTruncated）时必须抛 outputTruncated，不得把保留的尾部当完整监听列表而静默丢端口；改动 `PortScanner.scanPorts`/`interpretScanResult` 时优先跑 `PortOutputTruncationTests`。
- **Kill 身份复核**（#246，7 条）：由 `killRefusedWhenPidReusedByDifferentProcess`、`killRefusedWhenProcessAlreadyExited`、`killRefusedWhenScanBaselineMissing` 等用例锁定；kill 前必须复核进程启动时间与端口归属，PID 复用/进程退出/基线缺失/端口归属变化都必须拒绝 SIGKILL（fail-closed）；改动 `PortScanner.killProcess`/`ensureKillTargetStillValid`/`attachProcessStartTimes` 时优先跑 `PortKillIdentityTests`。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | v2PluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `v2PluginMetadataIsStable` |
| 2 | 综合 | parsesLsofListeningPorts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesLsofListeningPorts` |
| 3 | 综合 | ignoresMalformedLsofRows | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresMalformedLsofRows` |
| 4 | 综合 | ignoresLsofRowsWithInvalidPorts | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ignoresLsofRowsWithInvalidPorts` |
| 5 | 综合 | lsof 退出码 0 时扫描成功不抛错 | — | 调用 ensureScanSucceeded(exitCode: 0) | 不抛错 | P1 | ✅ 已覆盖 | `scanSucceedsOnExitZero` |
| 6 | 综合 | lsof 退出码 1 且 stderr 为空视为合法无匹配 | — | 调用 ensureScanSucceeded(exitCode: 1, stderr: "") | 不抛错（无端口） | P1 | ✅ 已覆盖 | `scanTreatsExitOneWithEmptyStderrAsNoMatch` |
| 7 | 综合 | 退出码 1 但 stderr 非空时抛错并透传 stderr 文案 | — | 调用 ensureScanSucceeded(exitCode: 1, stderr: 错误文案) | 抛 scanFailed，message 等于 stderr | P1 | ✅ 已覆盖 | `scanThrowsOnExitOneWithStderrMessage` |
| 8 | 综合 | 信号终止（退出码 15）且 stderr 为空必须抛 scanFailed，不得伪装无端口（**回归 #523**） | — | 调用 ensureScanSucceeded(exitCode: 15, stderr: "") | 抛 scanFailed，message 含退出码 15 | P0 | ✅ 已覆盖 | `scanThrowsOnSignalTerminationWithEmptyStderr` |
| 9 | 综合 | 取消导致的负信号退出码必须抛 scanFailed（**回归 #523**） | — | 调用 ensureScanSucceeded(exitCode: -15, stderr: "") | 抛 scanFailed | P0 | ✅ 已覆盖 | `scanThrowsOnCancelledNegativeSignalExit` |
| 10 | 综合 | 其他非零退出码且 stderr 为空必须抛 scanFailed | — | 调用 ensureScanSucceeded(exitCode: 2, stderr: "") | 抛 scanFailed | P1 | ✅ 已覆盖 | `scanThrowsOnOtherNonZeroExitWithEmptyStderr` |
| 11 | 输出截断 | lsof 退出码 0 但 stdout 被截断时抛 outputTruncated，不得把截尾当完整列表（**回归 #258**） | 构造 stdoutTruncated=true 的结果 | 调用 interpretScanResult | 抛 PortScannerError.outputTruncated | P0 | ✅ 已覆盖 | `scanThrowsWhenOutputTruncated` |
| 12 | 输出截断 | 输出完整时正常解析监听列表 | 构造 stdoutTruncated=false 的有效 lsof 文本 | 调用 interpretScanResult | 返回 1 个端口（node 3000） | P1 | ✅ 已覆盖 | `scanReturnsPortsWhenOutputComplete` |
| 13 | 输出截断 | 信号终止（退出码 15）经解释入口仍抛 scanFailed | 构造 exitCode=15 的结果 | 调用 interpretScanResult | 抛 PortScannerError | P0 | ✅ 已覆盖 | `scanThrowsOnSignalExitThroughSeam` |
| 14 | Kill 身份复核 | 解析 ps pid=,lstart= 输出为 PID→启动时间映射，跳过非法行（**回归 #246**） | 构造多行 ps 输出 | 调用 parseProcessStartTimes | 两个合法 PID 映射正确，非法行被忽略 | P1 | ✅ 已覆盖 | `parsesProcessStartTimesFromPsOutput` |
| 15 | Kill 身份复核 | 身份与端口均未变化时允许 kill（**回归 #246**） | 启动时间一致且端口仍在监听 | 调用 ensureKillTargetStillValid | 不抛错 | P1 | ✅ 已覆盖 | `killAllowedWhenIdentityAndPortUnchanged` |
| 16 | Kill 身份复核 | PID 被复用（启动时间变化）时必须拒绝 kill，不得误杀无关进程（**回归 #246**） | 当前启动时间与扫描基线不同 | 调用 ensureKillTargetStillValid | 抛 killTargetIdentityChanged | P0 | ✅ 已覆盖 | `killRefusedWhenPidReusedByDifferentProcess` |
| 17 | Kill 身份复核 | 进程已退出（查不到启动时间）时必须拒绝 kill（**回归 #246**） | currentStartTime 为 nil | 调用 ensureKillTargetStillValid | 抛 killTargetExited | P0 | ✅ 已覆盖 | `killRefusedWhenProcessAlreadyExited` |
| 18 | Kill 身份复核 | 扫描基线缺失无法验证身份时必须拒绝，不得放行（**回归 #246**） | expectedStartTime 为 nil | 调用 ensureKillTargetStillValid | 抛 killIdentityUnavailable | P0 | ✅ 已覆盖 | `killRefusedWhenScanBaselineMissing` |
| 19 | Kill 身份复核 | 身份未变但目标端口改由其他监听承载时不得执行 kill（**回归 #246**） | 当前监听列表只含其他端口 | 调用 ensureKillTargetStillValid | 抛 killTargetSocketChanged | P0 | ✅ 已覆盖 | `killRefusedWhenPortNoLongerOwned` |
| 20 | Kill 身份复核 | 进程不再监听任何端口时不得执行 kill（**回归 #246**） | 当前监听列表为空 | 调用 ensureKillTargetStillValid | 抛 killTargetSocketChanged | P0 | ✅ 已覆盖 | `killRefusedWhenProcessStopsListeningEntirely` |

> 说明：全部 **20 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> 变异验证（#258）：P-M1 删除 interpretScanResult 截断守卫 → `scanThrowsWhenOutputTruncated` 红；P-M2 守卫改判 stderrTruncated → `scanThrowsWhenOutputTruncated` 红；P-M3 删除 ensureScanSucceeded 调用 → `scanThrowsOnSignalExitThroughSeam` 红。均恢复后复绿。
> 变异验证（#246）：K-M1 移除 ensureKillTargetStillValid 全部守卫 → 5 条拒绝用例各自红（每条用例只触发一个守卫），放行用例保持绿；恢复后复绿。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 9 / 9
- P2: 已覆盖 1 / 1
- **合计: 20 / 20**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（9 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 20 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginPortManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
