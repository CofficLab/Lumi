# TestPlan — KitCADDesigner

## 包概述

KitCADDesigner 铝型材 3D 设计引擎（参考 MayCAD）—— 通过 3D 视口设计 T 型槽铝型材框架，自动生成物料清单（BOM）与切割优化方案。 本包只提供 CAD 引擎能力（模型 / 渲染 / 文档存储 / 视图），由插件 `PluginCADDesigner` 包装为 `SuperPlugin` 并注册 Agent 工具。 ## 功能 - **3D 视口**（SceneKit）：轨道相机、参考网格、XYZ 坐标轴、点击拾取选择组件 - **组件库**：欧标 20/30/40 系列铝型材（12 种规格）+ 连接件（角码、螺栓、滑块螺母、封端条、合页） - **参数化型材建模**：截面轮廓（矩形 + T 槽）+ `SCNShape` 拉伸 - **装配关系图**：组件间连接（rigid / hinge / bolt） - **物料清单（BOM）**：自动聚合相同规格型材与连接件 - **切割优化**：一维 First Fit Decreasing (FFD) 算法，最小化余料 - **项目保存/加载**：`.cadproj`（JSON）格式 - **截图导出**：视口 → PNG / PDF ## 目录结构 ``` Sources/KitCADDesigner/ ├── CADDesignerRuntimeBridge.swift # 数据目录注入 ├── Models/ # Codable 数据模型 ├── Core/ # 组件库、BOM、文档状态 ├── Services/ # 切割优化、保存加载、截图导出、本地化 ├── Renderer/ # S

平台: macOS 14+
测试文件: 1 个，用例总数: 14

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

- **CADDesignerLogic**（14 条）：由 `testTransform3DCodableRoundTrip`、`testCADDocumentCodableRoundTrip`、`testCADDocumentDecodeMissingFields` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 10 | CADDesignerLogic | testCutOptimizerOversizedDemandFiltered | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCutOptimizerOversizedDemandFiltered` |
| 11 | CADDesignerLogic | testComponentLibraryHasStandardProfiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testComponentLibraryHasStandardProfiles` |
| 12 | CADDesignerLogic | testComponentLibraryHasConnectors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testComponentLibraryHasConnectors` |
| 13 | CADDesignerLogic | testProfileWeightByLength | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testProfileWeightByLength` |
| 14 | CADDesignerLogic | testProjectSaveLoadRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testProjectSaveLoadRoundTrip` |

> 说明：全部 **14 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 13 / 13
- P2: 已覆盖 1 / 1
- **合计: 14 / 14**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（13 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+
- 14 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
