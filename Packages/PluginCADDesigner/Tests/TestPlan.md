# TestPlan — PluginCADDesigner

## 包概述

PluginCADDesigner 铝型材 CAD 设计插件：把 `KitCADDesigner` 引擎包装为 `SuperPlugin`，注册 10 个 `cad_*` Agent 工具， 并通过 `ContentViewProviding` 发布 3D 编辑工作区。

平台: macOS 14+
测试文件: 1 个，用例总数: 7

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `BuildFrameV2Tool`
- `CADDesignerPlugin`
- `CADDesignerV2ToolSupport`
- `ConnectComponentsV2Tool`
- `CreateCADProjectV2Tool`
- `GenerateBOMV2Tool`
- `LoadCADProjectV2Tool`
- `OptimizeCuttingV2Tool`
- `PlaceConnectorV2Tool`
- `PlaceProfileV2Tool`
- `SaveCADProjectV2Tool`
- `UpdateProfileV2Tool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CADDesignerSuperPlugin**（7 条）：由 `publishesWorkspace`、`createsProjectThroughV2Tool`、`savesAndLoadsProjectThroughV2Tools` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CADDesignerSuperPlugin | publishes the CAD workspace into the V2 content provider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `publishesWorkspace` |
| 2 | CADDesignerSuperPlugin | keeps the legacy create-project tool identifier | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createsProjectThroughV2Tool` |
| 3 | CADDesignerSuperPlugin | preserves CAD project save and load behavior | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `savesAndLoadsProjectThroughV2Tools` |
| 4 | CADDesignerSuperPlugin | builds the legacy frame shape through the V2 tool | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsFrameThroughV2Tool` |
| 5 | CADDesignerSuperPlugin | places and updates CAD components through stable V2 tool IDs | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placesAndUpdatesComponentsThroughV2Tools` |
| 6 | CADDesignerSuperPlugin | generates the CAD bill of materials through the V2 tool | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `generatesBOMThroughV2Tool` |
| 7 | CADDesignerSuperPlugin | connects components and optimizes profile cuts through V2 tools | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `connectsAndOptimizesThroughV2Tools` |

> 说明：全部 **7 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 6 / 6
- P2: 已覆盖 1 / 1
- **合计: 7 / 7**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（6 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+
- 7 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginCADDesigner
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
