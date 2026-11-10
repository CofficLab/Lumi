# TestPlan — PluginShowImage

## 包概述

PluginShowImage 的实现包，包含 3 个主要类型；当前测试覆盖 11 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 11

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ShowImageOverlay`
- `ShowImagePlugin`
- `ShowImageSource`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ShowImageTool**（7 条）：由 `imageSourcesNormalizeLocalAndRemoteLocations`、`imageSourceRejectsMissingAndUnsupportedSchemes`、`maximumWidthUsesDefaultAndClampsEveryInputForm` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ShowImageTool | imageSourcesNormalizeLocalAndRemoteLocations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageSourcesNormalizeLocalAndRemoteLocations` |
| 2 | ShowImageTool | imageSourceRejectsMissingAndUnsupportedSchemes | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `imageSourceRejectsMissingAndUnsupportedSchemes` |
| 3 | ShowImageTool | maximumWidthUsesDefaultAndClampsEveryInputForm | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `maximumWidthUsesDefaultAndClampsEveryInputForm` |
| 4 | ShowImageTool | executeValidatesLocalFilesAndPublishesNormalizedDisplayState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeValidatesLocalFilesAndPublishesNormalizedDisplayState` |
| 5 | ShowImageTool | 本地路径的首尾空白必须逐字节保留 | 文件名以空格结尾/开头 | 归一化 source 并执行工具 | 返回原始路径；存在该文件时成功显示 | P0 | ✅ 已覆盖 | `imageSourcePreservesLocalPathWhitespace` |
| 6 | ShowImageTool | 校验失败必须抛出错误，而不是返回 `Error: ...` 文本 | 缺失 source / 文件不存在 | 调用默认 `executeResult` | 抛出 `ShowImageError`；合法输入返回 `isError == false`（**回归** #765） | P0 | ✅ 已覆盖 | `validationFailuresThrowThroughExecuteResult` |
| 7 | ShowImageTool | 本地源必须是可读、可解码的普通文件 | 目录、伪造 `.png`、截断图片、不可读文件 | 调用 `executeResult` 指向以上路径 | 分别抛出 `notAFile` / `undecodableImage` / `unreadableFile`，且不发布显示状态（**回归** #766） | P0 | ✅ 已覆盖 | `rejectsDirectoryUnreadableAndUndecodableSources` |
| 8 | ShowImageTool | 拒绝缺少 host 的 HTTP(S) 远程地址（**回归 #1066**） | — | 归一化 `https:image.png`、`http:///image.png`、`https://user@:443/image.png` | 抛出 `missingRemoteHost`，不产生 `.remote` 来源 | P0 | ✅ 已覆盖 | `imageSourceRejectsRemoteURLWithoutHost` |
| 9 | ShowImageTool | 无 host 的远程地址不发布展示状态、不报告成功（**回归 #1066**） | `ShowImageState` 已清空 | 调用 `executeResult(source: https:image.png)` | 抛出 `missingRemoteHost`，`displayItem` 仍为 `nil` | P0 | ✅ 已覆盖 | `rejectsRemoteURLWithoutHostWithoutPublishing` |

| 10 | ShowImageTool | 保留 file URL 的 authority，拒绝非本地 host（**回归 #1094**） | — | 归一化 `file://server/...`、`file://files.corp.internal/...` | 抛出 `nonLocalFileHost`，不产生 `.local` 来源；空 authority 与 `localhost` 仍按本机文件处理 | P0 | ✅ 已覆盖 | `imageSourceRejectsNonLocalFileURLHost` |
| 11 | ShowImageTool | 非本地 file URL 不读取同名本机文件、不发布展示状态（**回归 #1094**） | 本机同路径存在有效图片 | 调用 `executeResult(source: file://server<path>)` | 抛出 `nonLocalFileHost`，`displayItem` 仍为 `nil` | P0 | ✅ 已覆盖 | `rejectsNonLocalFileURLWithoutPublishing` |

> 说明：全部 **11 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 2 / 2
- P2: 已覆盖 1 / 1
- **合计: 11 / 11**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（2 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 11 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginShowImage
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
