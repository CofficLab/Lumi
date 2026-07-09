# CADDesignerPlugin

铝型材 3D 设计插件（参考 MayCAD）—— 通过 3D 视口设计 T 型槽铝型材框架，自动生成物料清单（BOM）与切割优化方案。

完整方案见 `docs/cad-designer-plugin-proposal.md`。

## 功能

- **3D 视口**（SceneKit）：轨道相机、参考网格、XYZ 坐标轴、点击拾取选择组件
- **组件库**：欧标 20/30/40 系列铝型材（12 种规格）+ 连接件（角码、螺栓、滑块螺母、封端条、合页）
- **参数化型材建模**：截面轮廓（矩形 + T 槽）+ `SCNShape` 拉伸
- **装配关系图**：组件间连接（rigid / hinge / bolt）
- **物料清单（BOM）**：自动聚合相同规格型材与连接件
- **切割优化**：一维 First Fit Decreasing (FFD) 算法，最小化余料
- **项目保存/加载**：`.cadproj`（JSON）格式
- **截图导出**：视口 → PNG / PDF
- **AI 增强**：10 个 AgentTool，支持自然语言操作（如 "搭一个 1m×0.5m 工作台"）

## AI 工具

| 工具 | 说明 |
|------|------|
| `cad_create_project` | 创建新项目 |
| `cad_place_profile` | 放置型材 |
| `cad_update_profile` | 更新组件长度/位置/旋转 |
| `cad_place_connector` | 放置连接件 |
| `cad_connect_components` | 建立组件间连接 |
| `cad_generate_bom` | 生成物料清单 |
| `cad_optimize_cutting` | 切割优化 |
| `cad_save_project` | 保存项目 |
| `cad_load_project` | 加载项目 |
| `cad_build_frame` | 按尺寸自动生成矩形框架 |

## 目录结构

```
Sources/
├── CADDesignerPlugin.swift      # 插件入口
├── Models/                      # Codable 数据模型
├── Core/                        # 组件库、BOM、文档状态
├── Services/                    # 切割优化、保存加载、截图导出
├── Renderer/                    # SceneKit 视口、场景、几何体
├── Tools/                       # 交互工具状态
├── ViewModels/                  # 工作区视图模型
├── Views/                       # SwiftUI 视图
└── AgentTools/                  # AI AgentTool
```

## 技术栈

- **3D 引擎**：SceneKit（macOS 原生）
- **UI**：SwiftUI + NSViewRepresentable（嵌入 SCNView）
- **数据**：Codable + `@MainActor ObservableObject` Store（单例）
