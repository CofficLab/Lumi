# KitCADDesigner

铝型材 3D 设计引擎（参考 MayCAD）—— 通过 3D 视口设计 T 型槽铝型材框架，自动生成物料清单（BOM）与切割优化方案。

本包只提供 CAD 引擎能力（模型 / 渲染 / 文档存储 / 视图），由插件 `PluginCADDesigner` 包装为 `SuperPlugin` 并注册 Agent 工具。

## 功能

- **3D 视口**（SceneKit）：轨道相机、参考网格、XYZ 坐标轴、点击拾取选择组件
- **组件库**：欧标 20/30/40 系列铝型材（12 种规格）+ 连接件（角码、螺栓、滑块螺母、封端条、合页）
- **参数化型材建模**：截面轮廓（矩形 + T 槽）+ `SCNShape` 拉伸
- **装配关系图**：组件间连接（rigid / hinge / bolt）
- **物料清单（BOM）**：自动聚合相同规格型材与连接件
- **切割优化**：一维 First Fit Decreasing (FFD) 算法，最小化余料
- **项目保存/加载**：`.cadproj`（JSON）格式
- **截图导出**：视口 → PNG / PDF

## 目录结构

```
Sources/KitCADDesigner/
├── CADDesignerRuntimeBridge.swift   # 数据目录注入
├── Models/                          # Codable 数据模型
├── Core/                            # 组件库、BOM、文档状态
├── Services/                        # 切割优化、保存加载、截图导出、本地化
├── Renderer/                        # SceneKit 视口、场景、几何体
├── Tools/                           # 交互工具状态
├── ViewModels/                      # 工作区视图模型
└── Views/                           # SwiftUI 视图
```

## 技术栈

- **3D 引擎**：SceneKit（macOS 原生）
- **UI**：SwiftUI + NSViewRepresentable（嵌入 SCNView）
- **数据**：Codable + `@MainActor ObservableObject` Store（单例）

## Testing

```sh
swift test
```
