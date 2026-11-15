# TestPlan — PluginScreenRecorder

## 包概述

PluginScreenRecorder 的实现包，包含 14 个主要类型；当前测试覆盖 31 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 31

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Tools/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ScreenRecorderLocalization`
- `ScreenRecorderPlugin`
- `ScreenRecorderRuntime`
- `RecordingActivity`
- `ApplicationActivationObserver`
- `RecordingSessionObserverHandle`
- `RecordableWindow`
- `RecordingFileWriter`
- `RecordingPermissionService`
- `RecordingSessionManager`
- `ScreenCaptureRecorder`
- `RecordingToolSupport`
- `RecordingIndicatorModel`
- `ScreenRecorderAboutView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **RecordableWindowProvider**（4 条）：由 `matchByName`、`matchByBundleId`、`matchByTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RecordableWindowExistence**（4 条）：由 `unknownWindowReturnsFalse`、`zeroWindowIDReturnsFalse`、`queryWorksOffMainThread` 等用例锁定定向窗口存在性查询（#1272）；改动该模块时优先跑对应测试文件。
- **RecordingFileWriter**（3 条）：由 `tempURLShape`、`finalizeConflict`、`finalizeSanitizes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RecordingResolution**（8 条）：由 `heightOneIsRejected`、`nonPositiveHeightsAreRejected`、`outputSizeIsNeverZero` 等用例锁定高度 1 对齐后为 0 的拒绝路径（#866）；改动该模块时优先跑对应测试文件。
- **ScreenRecorderPlugin**（9 条）：由 `modelsInitialize`、`frameRateClamping`、`resolutionHeightAndDurationClamping` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RecordingSessionManagerConcurrency**（3 条）：由 `secondStartDuringTargetResolutionIsRejected`、`secondStartDuringMicrophonePermissionIsRejected`、`activeSessionRejectsSecondStartWithoutOverwrite` 锁定 start 的启动互斥必须从进入流程持有到会话建立（**#224**）；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | RecordableWindowProvider | 按应用名匹配返回首个 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchByName` |
| 2 | RecordableWindowProvider | 按 bundleId 精确匹配 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchByBundleId` |
| 3 | RecordableWindowProvider | 窗口标题子串进一步过滤 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `matchByTitle` |
| 4 | RecordableWindowProvider | 无匹配返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noMatch` |
| 5 | RecordingFileWriter | tempURL 落在 tmp 子目录且为 mp4 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tempURLShape` |
| 6 | RecordingFileWriter | finalize 移动文件并按冲突追加序号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `finalizeConflict` |
| 7 | RecordingFileWriter | finalize 清洗非法文件名字符 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `finalizeSanitizes` |
| 8 | ScreenRecorderPlugin | Models initialize | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelsInitialize` |
| 9 | ScreenRecorderPlugin | frameRate 被钳制到 1...60 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `frameRateClamping` |
| 10 | ScreenRecorderPlugin | 错误描述非空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptions` |
| 11 | ScreenRecorderPlugin | 新版工具保留录制契约 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2ToolsPreserveRecordingContract` |
| 12 | ScreenRecorderPlugin | resolution_height 与 duration_seconds 被钳制，避免极大值在像素换算时溢出 Int 终止进程 | — | 以 `Int.max` / 负数构造 `RecordingConfig` | 高度钳制到 1...4320，时长钳制到 1...3600 | P0 | ✅ 已覆盖 | `resolutionHeightAndDurationClamping` |
| 13 | ScreenRecorderPlugin | 麦克风采集仅在 macOS 15+ 可用 | — | 调用 `RecordingMicrophoneCapability.isSupported(majorVersion:)` | 14 为 false，15/26 为 true | P1 | ✅ 已覆盖 | `microphoneCapabilityDependsOnMajorVersion` |
| 14 | ScreenRecorderPlugin | macOS 14 请求麦克风时明确报错，未请求则放行 | — | 调用 `RecordingMicrophoneCapability.validate` | 14+麦克风抛错，其余组合不抛 | P1 | ✅ 已覆盖 | `microphoneValidationRejectsUnsupportedVersions` |
| 15 | ScreenRecorderPlugin | macOS 14 上 start 在权限检查前拒绝麦克风录制 | 注入主版本号 14 | 调用 `RecordingSessionManager.start` | 抛 `microphoneUnsupported`，不进入录制态 | P0 | ✅ 已覆盖 | `startRejectsMicrophoneBeforePermissionsOnMacOS14` |
| 16 | ScreenRecorderPlugin | 缺少 application 时抛出 `ToolExecutionError`，不返回错误字符串 | 无 | 调用 `start_recording(target: app_window)` 不传 application | 抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `startRecordingThrowsWhenApplicationIsMissing` |
| 17 | RecordingResolution | 高度 1 必须在启动前被拒绝（偶数对齐后为 0，**回归 #866**） | — | 调用 `RecordingResolution.validate(height: 1)` | 抛出 `RecordingError` | P0 | ✅ 已覆盖 | `heightOneIsRejected` |
| 18 | RecordingResolution | 高度 0 与负数不得放行（**回归 #866**） | — | 调用 `validate(height: 0)` / `validate(height: -10)` | 均抛出 `RecordingError` | P0 | ✅ 已覆盖 | `nonPositiveHeightsAreRejected` |
| 19 | RecordingResolution | 高度 2 及以上与「跟随源尺寸」都被放行 | — | 调用 `validate(height: 2/1080/nil)` | 均不抛错 | P1 | ✅ 已覆盖 | `validHeightsPass` |
| 20 | RecordingResolution | 拒绝时给出具体的参数错误 | — | 捕获 `validate(height: 1)` 的错误 | `invalidResolutionHeight(1)`，描述含请求高度 | P1 | ✅ 已覆盖 | `rejectionCarriesTheRequestedHeight` |
| 21 | RecordingResolution | 输出尺寸对齐后不得为 0（**回归 #866**） | contentSize 1920x1080 | `computeOutputSize(resolutionHeight: 1)` | 宽高均 ≥ 2 | P0 | ✅ 已覆盖 | `outputSizeIsNeverZero` |
| 22 | RecordingResolution | 合法的分辨率仍然按偶数对齐 | contentSize 1920x1080 | `computeOutputSize(resolutionHeight: 1081)` | 高度 1080，宽度为偶数 | P1 | ✅ 已覆盖 | `validResolutionStaysEven` |
| 23 | RecordingResolution | 工具在参数层就拒绝高度 1 | — | `StartRecordingV2Tool.execute(resolution_height: 1)` | 抛错且描述提示最小高度 2 | P1 | ✅ 已覆盖 | `toolRejectsHeightOne` |
| 24 | RecordingResolution | start 在权限检查前就拒绝非法高度 | resolutionHeight 1 | 调用 `RecordingSessionManager.start` | 抛 `invalidResolutionHeight`，不进入录制态 | P1 | ✅ 已覆盖 | `startRejectsInvalidHeightBeforePermissions` |
| 25 | RecordableWindowExistence | 不存在的窗口 ID 返回 false | 极大且不存在的窗口号 | 调用 `windowExists(id:)` | 返回 false，不误命中 | P1 | ✅ 已覆盖 | `unknownWindowReturnsFalse` |
| 26 | RecordableWindowExistence | 窗口 ID 0 返回 false | — | 调用 `windowExists(id: 0)` | 返回 false | P2 | ✅ 已覆盖 | `zeroWindowIDReturnsFalse` |
| 27 | RecordableWindowExistence | 查询在后台线程也能得到一致结果 | Task.detached 后台执行 | 调用 `windowExists(id:)` | 与主线程一致返回 false | P1 | ✅ 已覆盖 | `queryWorksOffMainThread` |
| 28 | RecordableWindowExistence | 当前 app 至少有一个窗口可被发现 | 测试进程通常无窗口 | 调用 `windowExists(id: 1)` | 查询不崩溃且返回布尔 | P2 | ✅ 已覆盖 | `currentAppHasDiscoverableWindow` |
| 29 | RecordingSessionManagerConcurrency | 目标解析期间的第二个 start 必须被拒绝 alreadyRecording，不得覆盖先到者（**回归 #224**） | 注入权限放行与门闩式目标解析，第一个 start 停在解析 await | 并发发起第二个 start，随后放行门闩 | 第二个抛 alreadyRecording；第一个按自己的路径收尾；失败后互斥释放可再次 start | P0 | ✅ 已覆盖 | `secondStartDuringTargetResolutionIsRejected` |
| 30 | RecordingSessionManagerConcurrency | 麦克风权限等待期间的第二个 start 必须被拒绝 alreadyRecording，不得重复触发权限弹窗（**回归 #224**） | 注入屏幕权限放行、麦克风未授权与挂起的权限请求，第一个 start 停在权限 await | 并发发起第二个 start，随后以拒绝收尾权限请求 | 第二个抛 alreadyRecording 且权限请求只触发一次；第一个以 microphonePermissionDenied 收尾 | P0 | ✅ 已覆盖 | `secondStartDuringMicrophonePermissionIsRejected` |
| 31 | RecordingSessionManagerConcurrency | 已建立的会话拒绝第二个 start 且不被覆盖（**回归 #224**） | 注入空操作引擎桩建立活动会话 | 再次调用 start | 抛 alreadyRecording，会话 id 与活跃状态不变 | P0 | ✅ 已覆盖 | `activeSessionRejectsSecondStartWithoutOverwrite` |

> 说明：全部 **31 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（**#224**，`RecordingSessionManager.start` 启动互斥）：
> - **M1** 去掉 `|| isStarting`（只查 `hasActiveSession`）→ `secondStartDuringTargetResolutionIsRejected`、`secondStartDuringMicrophonePermissionIsRejected` 转红（第二个 start 未被拒绝，挂起在与第一个相同的 await 上，且重复触发权限请求）；`activeSessionRejectsSecondStartWithoutOverwrite` 仍绿。
> - **M2** 把互斥占有移回权限 await 之后（保留 isStarting）→ `secondStartDuringMicrophonePermissionIsRejected` 转红（第二个请求再次进入麦克风权限等待），目标解析用例仍绿。
> - 还原完整修复（任何 await 之前占有 isStarting，defer 释放，权限/解析/引擎经注入点可测）→ 31 条全绿。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 20 / 20
- P2: 已覆盖 3 / 3
- **合计: 31 / 31**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（20 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 31 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginScreenRecorder
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
