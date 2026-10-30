# TestPlan — PluginScreenRecorder

## 包概述

PluginScreenRecorder 的实现包，包含 14 个主要类型；当前测试覆盖 11 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 11

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
- **RecordingFileWriter**（3 条）：由 `tempURLShape`、`finalizeConflict`、`finalizeSanitizes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ScreenRecorderPlugin**（4 条）：由 `modelsInitialize`、`frameRateClamping`、`errorDescriptions` 等用例锁定；改动该模块时优先跑对应测试文件。

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

> 说明：全部 **11 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 10 / 10
- P2: 已覆盖 1 / 1
- **合计: 11 / 11**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 11 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
