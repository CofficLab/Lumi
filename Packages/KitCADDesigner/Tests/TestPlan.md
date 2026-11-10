# TestPlan — KitCADDesigner

## 包概述

KitCADDesigner 铝型材 3D 设计引擎（参考 MayCAD）—— 通过 3D 视口设计 T 型槽铝型材框架，自动生成物料清单（BOM）与切割优化方案。 本包只提供 CAD 引擎能力（模型 / 渲染 / 文档存储 / 视图），由插件 `PluginCADDesigner` 包装为 `SuperPlugin` 并注册 Agent 工具。 ## 功能 - **3D 视口**（SceneKit）：轨道相机、参考网格、XYZ 坐标轴、点击拾取选择组件 - **组件库**：欧标 20/30/40 系列铝型材（12 种规格）+ 连接件（角码、螺栓、滑块螺母、封端条、合页） - **参数化型材建模**：截面轮廓（矩形 + T 槽）+ `SCNShape` 拉伸 - **装配关系图**：组件间连接（rigid / hinge / bolt） - **物料清单（BOM）**：自动聚合相同规格型材与连接件 - **切割优化**：一维 First Fit Decreasing (FFD) 算法，最小化余料 - **项目保存/加载**：`.cadproj`（JSON）格式 - **截图导出**：视口 → PNG / PDF ## 目录结构 ``` Sources/KitCADDesigner/ ├── CADDesignerRuntimeBridge.swift # 数据目录注入 ├── Models/ # Codable 数据模型 ├── Core/ # 组件库、BOM、文档状态 ├── Services/ # 切割优化、保存加载、截图导出、本地化 ├── Renderer/ # S

平台: macOS 14+
测试文件: 1 个，用例总数: 25

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConnectionType`
- `BOMItem`
- `BOMTableView`
- `CADDesignerAboutView`
- `CADDesignerLocalization`
- `CADDesignerManualView`
- `CADDesignerRuntimeBridge`
- `CADDesignerView`
- `CADDocument`
- `CADDocumentStore`
- `CADSceneController`
- `CADToolKind`
- `CADViewportSceneView`
- `CADViewportView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CADDesignerLogic**（25 条）：由 `testTransform3DCodableRoundTrip`、`testCADDocumentCodableRoundTrip`、`testCADDocumentDecodeMissingFields` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CADDesignerLogic | testTransform3DCodableRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTransform3DCodableRoundTrip` |
| 2 | CADDesignerLogic | testCADDocumentCodableRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCADDocumentCodableRoundTrip` |
| 3 | CADDesignerLogic | testCADDocumentDecodeMissingFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCADDocumentDecodeMissingFields` |
| 4 | CADDesignerLogic | testBOMAggregationGroupsIdenticalProfiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBOMAggregationGroupsIdenticalProfiles` |
| 5 | CADDesignerLogic | testBOMWeightCalculation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBOMWeightCalculation` |
| 6 | CADDesignerLogic | testCutOptimizerFFDPacking | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCutOptimizerFFDPacking` |
| 7 | CADDesignerLogic | testCutOptimizerMultipleStocks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCutOptimizerMultipleStocks` |
| 8 | CADDesignerLogic | testCutOptimizerFFDMergesSmallDemands | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCutOptimizerFFDMergesSmallDemands` |
| 9 | CADDesignerLogic | testCutOptimizerEmptyDemands | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testCutOptimizerEmptyDemands` |
| 10 | CADDesignerLogic | 超长需求不参与排料但必须被报告 | — | 执行该用例 | 单独确认 `unschedulableDemands == [7000]`，其余需求正常排入 | P1 | ✅ 已覆盖 | `testCutOptimizerReportsOversizedDemand` |
| 11 | CADDesignerLogic | testComponentLibraryHasStandardProfiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testComponentLibraryHasStandardProfiles` |
| 12 | CADDesignerLogic | testComponentLibraryHasConnectors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testComponentLibraryHasConnectors` |
| 13 | CADDesignerLogic | testProfileWeightByLength | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testProfileWeightByLength` |
| 14 | CADDesignerLogic | testProjectSaveLoadRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testProjectSaveLoadRoundTrip` |
| 15 | CADDesignerLogic | 原生 .cadproj 扩展可被 Load/Save 面板接受 | — | 执行该用例 | `.cadDesignerProject` 声明 cadproj 扩展并 conform 到 JSON | P1 | ✅ 已覆盖 | `testNativeProjectContentTypeAcceptsCadprojExtension` |
| 16 | CADDesignerLogic | 全部需求超长时仍报告无法排入的组件 | 需求 [8000, 7000]，原料 6000 | 执行该用例 | `stockCount == 0` 且 `unschedulableDemands == [8000, 7000]` | P1 | ✅ 已覆盖 | `testCutOptimizerReportsOnlyUnschedulableDemands` |
| 17 | CADDesignerLogic | 不同小数切割长度不得被 BOM 合并 | 同规格 500.25 与 500.75 两根型材 | 执行该用例 | 生成 2 行、数量各 1，描述分别含 500.25mm / 500.75mm | P0 | ✅ 已覆盖 | `testBOMKeepsDistinctFractionalLengths` |
| 18 | CADDesignerLogic | 修改位置不得重置其他旋转轴和缩放 | 初始 rotationX=15, rotationY=30, rotationZ=90, scale=2 | 调用 `updatePlacement` 更新位置与 Y 旋转 | 位置和 rotationY 更新，rotationX/Z 与 scale 保持不变 | P0 | ✅ 已覆盖 | `testPlacementUpdatePreservesOtherTransformComponents` |
| 19 | CADDesignerLogic | Undo 回退内容时组件 ID 不变，属性面板需按值同步 | 长度 500 → 1000 → Undo | 执行该用例 | Undo 后 ID 不变、长度回到 500（证明同步键不能只看 ID） | P1 | ✅ 已覆盖 | `testUndoRestoresComponentValuesWithoutChangingId` |
| 20 | CADDesignerLogic | Measure 模式点击两个组件后计算距离 | 两组件位置 (0,0,0) 与 (3,4,0) | 调用 `handleViewportPick` 两次 | 第一次无结果，第二次距离为 5 且记录两端组件 ID | P1 | ✅ 已覆盖 | `testMeasureToolComputesDistanceFromTwoPicks` |
| 21 | CADDesignerLogic | 旧切割方案保留其计算时使用的原料长度 | 以 6000mm 优化后把输入改为 1000mm，不重新优化 | 读取 `cutResult.stockLength` | 仍为 6000，不被新输入改写 | P1 | ✅ 已覆盖 | `testCutResultKeepsStockLengthUsedForOptimization` |
| 22 | CADDesignerLogic | Finder 打开方式投递的项目 URL 应加载为选中项目 | 存盘后重置 store，工作区自动创建空项目 | 调用 `openProjectURL` 传入 `.cadproj` 的 file URL | 选中项目变为文件中的项目，组件数一致，`lastExportURL` 指向该文件 | P1 | ✅ 已覆盖 | `testOpenProjectURLFromFileAssociationLoadsSelectedProject` |
| 23 | CADDesignerLogic | 非项目扩展名被拒绝且不替换当前工作区 | 已选中名为 Keep Me 的文档 | 调用 `openProjectURL` 传入 `.txt` 文件 | 当前项目不变，文档数不变，`lastError` 非空 | P1 | ✅ 已覆盖 | `testOpenProjectURLRejectsUnsupportedExtensionWithoutReplacingWorkspace` |
| 24 | CADDesignerLogic | 损坏的项目文件报错且不替换当前工作区 | 已选中名为 Keep Me 的文档 | 调用 `openProjectURL` 传入无法解码的 `.cadproj` 文件 | 当前项目不变，文档数不变，`lastError` 非空 | P1 | ✅ 已覆盖 | `testOpenProjectURLReportsUndecodableFileWithoutReplacingWorkspace` |
| 25 | CADDesignerLogic | 连接端点不在当前文档时拒绝写入（**回归 #1077**） | 文档含 1 根型材与 1 个连接件 | 分别用两个不存在的 ID、以及「存在 → 不存在」的端点调用 `addConnection` | 抛 `componentNotFound`，连接数保持 0；两端都存在时正常写入并得到 1 条连接 | P0 | ✅ 已覆盖 | `testAddConnectionRejectsUnknownEndpoints` |

> 说明：全部 **25 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 21 / 21
- P2: 已覆盖 1 / 1
- **合计: 25 / 25**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（21 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+
- 25 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitCADDesigner
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
