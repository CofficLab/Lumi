# TestPlan — PluginChatScreenshot

## 包概述

PluginChatScreenshot 的实现包，包含 10 个主要类型；当前测试覆盖 28 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 28

核心组件（源码目录）:
- `Capture/`
- `Models/`
- `Overlay/`
- `Support/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ChatScreenshotPlugin`
- `ScreenCapturePermissionPrompter`
- `ScreenCaptureService`
- `ScreenshotFileWriter`
- `ChatScreenshotState`
- `ChatScreenshotOverlayController`
- `ChatScreenshotOverlayView`
- `ChatScreenshotOverlayWindow`
- `ScreenshotFlowRunner`
- `ChatScreenshotButtonView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ChatScreenshotCrop**（5 条）：锁定 `ChatScreenshotState.crop` 的取整、越界裁剪与 Y 轴翻转。
- **截图文件写入器缩放**（4 条）：锁定 `ScreenshotFileWriter` 长边等比缩放与常量上限。
- **截图文件写入器编码**（6 条）：锁定 JPEG 编码、文件名生成、落盘与附件字段。
- **Chat Screenshot 插件生命周期**（6 条）：锁定按钮与命令组的注册/注销。
- **Chat Screenshot 权限请求**（3 条）：锁定 `ScreenCapturePermissionPrompter.ensurePermission` 必须先 preflight、未授权时补发系统授权请求。
- **遮罩视图引用环**（1 条）：锁定 `ChatScreenshotOverlayController.wireCallbacks` 的闭包对视图弱捕获，装配回调后视图仍可释放。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ChatScreenshotCrop | cropReturnsImageForValidSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cropReturnsImageForValidSelection` |
| 2 | ChatScreenshotCrop | cropReturnsNilForOutOfImageSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cropReturnsNilForOutOfImageSelection` |
| 3 | ChatScreenshotCrop | cropClampsSelectionToImageBounds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cropClampsSelectionToImageBounds` |
| 4 | ChatScreenshotCrop | cropFlipsYAxis | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cropFlipsYAxis` |
| 5 | ChatScreenshotCrop | screenshotAttachmentContainsEncodedJpeg | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `screenshotAttachmentContainsEncodedJpeg` |
| 6 | 截图文件写入器缩放 | keepsSmallImage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsSmallImage` |
| 7 | 截图文件写入器缩放 | scalesDownLongestSide | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scalesDownLongestSide` |
| 8 | 截图文件写入器缩放 | skipsScalingForNonPositiveLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsScalingForNonPositiveLimit` |
| 9 | 截图文件写入器缩放 | scalesPortraitImage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scalesPortraitImage` |
| 10 | 截图文件写入器编码 | defaultConstants | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultConstants` |
| 11 | 截图文件写入器编码 | encodesJPEGData | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodesJPEGData` |
| 12 | 截图文件写入器编码 | buildsFileName | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsFileName` |
| 13 | 截图文件写入器编码 | writesFileToDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writesFileToDirectory` |
| 14 | 截图文件写入器编码 | buildsAttachment | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsAttachment` |
| 15 | 截图文件写入器编码 | attachmentDownscalesLargeImage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attachmentDownscalesLargeImage` |
| 16 | 截图文件写入器编码 | rejectsEmptyCaptureFrame | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsEmptyCaptureFrame` |
| 17 | 截图文件写入器编码 | rejectsDisjointSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsDisjointSelection` |
| 18 | 截图文件写入器编码 | cropsSubPixelSelectionToOnePixel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cropsSubPixelSelectionToOnePixel` |
| 19 | 插件生命周期 | pluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 20 | 插件生命周期 | bootRegistersBarItemAndCommandGroup | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootRegistersBarItemAndCommandGroup` |
| 21 | 插件生命周期 | bootWithoutChatSectionProviderIsNoop | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutChatSectionProviderIsNoop` |
| 22 | 插件生命周期 | bootWithoutProvidersIsNoop | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutProvidersIsNoop` |
| 23 | 插件生命周期 | shutdownRemovesContributions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesContributions` |
| 24 | 插件生命周期 | shutdownWithoutProvidersIsNoop | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownWithoutProvidersIsNoop` |
| 25 | 权限请求 | requestsSystemPromptWhenNotAuthorized | TCC 未授权 | preflight=false 时调用 ensurePermission | 触发 request 并返回 true | P0 | ✅ 已覆盖 | `requestsSystemPromptWhenNotAuthorized` |
| 26 | 权限请求 | skipsRequestWhenAlreadyAuthorized | TCC 已授权 | preflight=true 时调用 ensurePermission | 不触发 request 并返回 true | P1 | ✅ 已覆盖 | `skipsRequestWhenAlreadyAuthorized` |
| 27 | 权限请求 | returnsFalseWhenRequestDenied | 用户拒绝授权 | preflight=false、request=false | 返回 false | P1 | ✅ 已覆盖 | `returnsFalseWhenRequestDenied` |
| 28 | 遮罩视图引用环 | overlayViewDeallocatesAfterCallbacksAreWired | 控制器与视图均为局部强引用 | 装配回调后离开作用域并 drain 自动释放池 | 视图弱引用为 nil（无泄漏） | P0 | ✅ 已覆盖 | `overlayViewDeallocatesAfterCallbacksAreWired` |

> 说明：全部 **28 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 24 / 24
- P2: 已覆盖 2 / 2
- **合计: 28 / 28**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（24 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 28 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginChatScreenshot
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
