# TestPlan — PluginImageToPDF

## 包概述

PluginImageToPDF 的实现包，包含 12 个主要类型；当前测试覆盖 17 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 17

核心组件（源码目录）:
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ImageItem`
- `PDFOutputStatus`
- `ImageToPDFLocalization`
- `ImageToPDFRuntimeBridge`
- `ImageToPDFService`
- `ImageToPDFViewModel`
- `ImageDropZoneView`
- `ImageListRow`
- `ImageToPDFAboutView`
- `ImageToPDFMainView`
- `ImageToPDFManualView`
- `PDFOutputRow`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ImageToPDFPlugin**（1 条）：由 `activatingPluginHidesChatSectionAndDeactivatingRestoresIt` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ImageToPDFViewModel**（10 条）：由 `managesImageInputs`、`rejectsUnreadableImage`、`collectsConcurrentDropResults`、`duplicateFileNamesProduceDistinctPDFs`、`failedConversionDoesNotReportStalePDFAsDone`、`failureSummaryReportsActualCount`、`clearAvailabilityTracksInputsAndOutputs`、`exportRejectsDirectoryConflictAndPreservesContents`、`exportFailurePreservesExistingFile`、`exportReplacesExistingFileOnSuccess` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PDFOutputItem**（5 条）：由 `testInitialStatusIsPending`、`testDoneStatusExposesOutputURL`、`testFailedStatusIsTerminal`、`testFailedStatusStopsShowingProgress`、`testDoneStatusStopsShowingProgress` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ImageToPDFService**（1 条）：由 `preservesVerticalOrientation` 锁定 PDF 页面的上下方向与源图一致；改动绘制逻辑时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ImageToPDFPlugin | activatingPluginHidesChatSectionAndDeactivatingRestoresIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginHidesChatSectionAndDeactivatingRestoresIt` |
| 2 | ImageToPDFViewModel | accepts unique image URLs and supports removing and clearing inputs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `managesImageInputs` |
| 3 | ImageToPDFViewModel | invalid image input ends conversion without creating a PDF | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsUnreadableImage` |
| 4 | ImageToPDFViewModel | collects URLs safely when file-provider callbacks arrive concurrently | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `collectsConcurrentDropResults` |
| 5 | PDFOutputItem | testInitialStatusIsPending | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInitialStatusIsPending` |
| 6 | PDFOutputItem | testDoneStatusExposesOutputURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDoneStatusExposesOutputURL` |
| 7 | PDFOutputItem | testFailedStatusIsTerminal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFailedStatusIsTerminal` |
| 8 | ImageToPDFViewModel | 同名不同目录的图片生成独立 PDF，导出不互相覆盖 | 两个目录下各有一张 `photo.png` | 加入两张图 → `convertAll` → 导出到空目录 | 两个输出项指向不同文件名，导出目录得到 2 个 PDF | P0 | ✅ 已覆盖 | `duplicateFileNamesProduceDistinctPDFs` |
| 9 | ImageToPDFViewModel | 转换失败时不把暂存目录里的旧同名 PDF 标记为成功 | 非法图片 `photo.png` + 暂存目录已有旧 `photo.pdf` | `convertAll` 后检查输出项状态 | 状态为 `.failed` 且错误信息包含文件名，旧 PDF 被清理 | P0 | ✅ 已覆盖 | `failedConversionDoesNotReportStalePDFAsDone` |
| 10 | ImageToPDFService | PDF 上下方向与源图一致，不产生垂直镜像 | 80×80 PNG，上半红下半蓝 | `convert` → 取第 0 页 `thumbnail` → 采样顶部/底部像素 | 顶部为红、底部为蓝 | P0 | ✅ 已覆盖 | `preservesVerticalOrientation` |
| 11 | ImageToPDFViewModel | 转换失败汇总显示真实失败数量，不出现畸形格式符 | 两张内容非法的 `a.png`、`b.png` | `convertAll` 后读取 `lastErrorMessage` | 文案包含失败数 2，且不含无效格式符产物 `0.000000` | P1 | ✅ 已覆盖 | `failureSummaryReportsActualCount` |
| 12 | ImageToPDFViewModel | 仅有输入图片也可 Clear，清空后恢复为不可用 | 一张有效 PNG | 依次检查空态、仅输入、仅输出、清空后的 `canClear` | 输入或输出任一非空为 true，全空为 false | P1 | ✅ 已覆盖 | `clearAvailabilityTracksInputsAndOutputs` |
| 13 | PDFOutputItem | 失败终态不再显示进行中进度条 | 进度为 0.1 的 processing 项 | 状态改为 `.failed` 后检查 `showsProgress` | `showsProgress` 为 false，进度值保留 | P1 | ✅ 已覆盖 | `testFailedStatusStopsShowingProgress` |
| 14 | PDFOutputItem | 完成终态不再显示进行中进度条 | 进度为 0.9 的项 | 状态改为 `.done` | `showsProgress` 为 false | P1 | ✅ 已覆盖 | `testDoneStatusStopsShowingProgress` |
| 15 | ImageToPDFViewModel | 导出目标是同名目录时拒绝并保留目录内容 | 有效 `photo.png` 转换成功；导出目录预存同名目录 `photo.pdf/keep.txt` | `convertAll` → `exportAll` | 写入数 0，`photo.pdf` 仍是目录且 `keep.txt` 内容保留，错误信息含 `photo.pdf` | P0 | ✅ 已覆盖 | `exportRejectsDirectoryConflictAndPreservesContents` |
| 16 | ImageToPDFViewModel | 导出复制失败时保留目标目录里的旧同名 PDF | 转换成功后删除暂存源；导出目录已有旧 `photo.pdf` 文件 | `exportAll`（复制必然失败） | 写入数 0，旧 `photo.pdf` 内容不变，`lastErrorMessage` 非空 | P0 | ✅ 已覆盖 | `exportFailurePreservesExistingFile` |
| 17 | ImageToPDFViewModel | 导出覆盖已存在的同名 PDF 文件时成功替换内容 | 有效 `photo.png` 转换成功；导出目录已有旧 `photo.pdf` 文件 | `exportAll` | 写入数 1，目标仍是文件且内容被替换，无 `.export-` 临时残留 | P1 | ✅ 已覆盖 | `exportReplacesExistingFileOnSuccess` |

> 说明：全部 **17 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 回归 #469（导出同名目录被递归删除 / 复制失败提前销毁旧文件）变异验证：
> - M1 去掉 `isDirectory` 类型冲突判断（恢复无条件 `removeItem`）→ 用例 15 RED（目录与 `keep.txt` 被删）。
> - M2 改回「先 `removeItem(destination)` 再 `copyItem`」→ 用例 16 RED（复制失败时旧 `photo.pdf` 已被删）。
> - M3 成功后不清理/不消费临时文件（`copyItem` 直接写 destination 且保留 `.export-` 副本）→ 用例 17 RED（临时残留）。
> 三处变异各自独立命中对应用例，恢复后全部 GREEN。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 10 / 10
- P2: 已覆盖 0 / 0
- **合计: 17 / 17**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 17 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginImageToPDF
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
