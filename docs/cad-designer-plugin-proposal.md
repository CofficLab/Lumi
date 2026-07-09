# CADDesignerPlugin（铝型材 3D 设计插件）研究与实现方案

## 1. 研究背景

### 1.1 MayCAD 产品分析

MayCAD 是德国 MayTec 公司开发的专用 3D/2D CAD 设计软件，核心面向 **T 型槽铝型材（Aluminum Profile）系统设计**，广泛应用于家具制造、工业设计、自动化设备和 DIY 领域。

#### 1.1.1 核心功能

| 功能 | 说明 |
|------|------|
| **3D/2D 设计** | 拖拽式操作，无需 CAD 经验即可创建 3D 配置和 2D 图纸 |
| **预制组件库** | 内置欧标铝型材（20/30/40 系列）和连接器，拖拽放置 |
| **智能连接** | 自动选择并放置所需连接件/配件 |
| **物料清单 (BOM)** | 自动生成带零件号识别的物料清单 |
| **切割优化** | 自动优化型材切割方案，减少浪费 |
| **2D 工程图** | 自动生成标准 2D 工程图纸 |
| **STEP 导出** | 导出 3D STEP 格式，供 SolidWorks 等 CAD 软件使用 |
| **工程交换** | 与工程部门直接交换图纸、零件列表和计算 |

#### 1.1.2 技术特点

- **平台**: Windows（120 MB）
- **语言**: 英语 / 德语
- **用户群**: 全球超过 5,000 家企业使用
- **定位**: 低门槛（无 CAD 经验可用）+ 专业输出（STEP / BOM / 2D 图纸）

#### 1.1.3 工作流

```
选择型材 → 拖拽放置 → 调整尺寸/位置 → 添加连接件 → 自动生成 BOM → 导出 STEP/2D 图纸
```

### 1.2 竞品与替代方案参考

| 软件 | 特点 | 参考点 |
|------|------|--------|
| **MayCAD (MayTec)** | 铝型材专用，拖拽式设计 | 核心参考对象 |
| **80/20 Inc CAD** | 美国铝型材品牌自带 CAD 工具 | 组件库组织方式 |
| **item CAD (item Industrietechnik)** | 德国 item 品牌的在线 CAD | 参数化建模 |
| **iCADMac** | macOS 原生 2D/3D CAD | macOS 平台适配参考 |
| **FreeCAD** | 开源 3D 参数化 CAD | 开源架构参考 |

---

## 2. 需求定义

### 2.1 目标范围（MVP）

| 维度 | 定义 |
|------|------|
| **平台** | 仅 macOS |
| **型材标准** | 欧标（20 系列 / 30 系列 / 40 系列） |
| **STEP 导出** | MVP 阶段不实现，后期可扩展 |
| **品类范围** | 仅铝型材 + 基础连接件 |
| **设计模式** | 3D 为主，2D 图纸 MVP 阶段简化为俯视图/正视图截图导出 |

### 2.2 用户故事

1. 作为设计师，我可以从组件面板浏览并拖拽欧标铝型材到 3D 视口中
2. 作为设计师，我可以调整型材的长度、位置和旋转角度
3. 作为设计师，我可以添加角码/螺栓等连接件将型材组装在一起
4. 作为设计师，我可以查看当前项目的物料清单（BOM）
5. 作为设计师，我可以将项目保存并在后续打开继续编辑
6. 作为设计师，我可以导出当前设计的 2D 截图（PNG/PDF）用于分享

---

## 3. 技术架构

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│ 应用装配层 (LumiApp)                                             │
│  LumiPluginRegistry — 注册 CADDesignerPlugin                     │
└────────────────────────────┬────────────────────────────────────┘
                             │ 插件注册
┌────────────────────────────▼────────────────────────────────────┐
│ 插件层 (Plugins/CADDesignerPlugin/)                              │
│  ┌─ UI Shell ─────────────────────────────────────────────┐     │
│  │ CADWorkspaceView — 主工作区（3D 视口 + 侧边面板 + 工具栏）│     │
│  │ ComponentPaletteView — 组件库面板                        │     │
│  │ BOMTableView — 物料清单表格                              │     │
│  │ ToolBarView — 绘图工具栏                                 │     │
│  └──────────────────────────────────────────────────────────┘     │
│  ┌─ ViewModel 层 ───────────────────────────────────────────┐    │
│  │ CADWorkspaceViewModel — 工作区状态管理                     │    │
│  │ ComponentPaletteVM — 组件库浏览/搜索                      │    │
│  │ BOMViewModel — BOM 数据汇总与展示                         │    │
│  └──────────────────────────────────────────────────────────┘     │
│  ┌─ Tool 层 ────────────────────────────────────────────────┐    │
│  │ SelectTool / PlaceComponentTool / ConnectTool / MeasureTool│   │
│  └──────────────────────────────────────────────────────────┘     │
│  ┌─ Service 层 ─────────────────────────────────────────────┐    │
│  │ ComponentCatalogLoader / BOMGenerator / CutOptimizer       │    │
│  │ ProjectSaveLoadService / ScreenshotExporter                │    │
│  └──────────────────────────────────────────────────────────┘     │
│  ┌─ Renderer 层 ────────────────────────────────────────────┐    │
│  │ CADViewport (SceneKit) / ComponentRenderer / HitTester     │    │
│  └──────────────────────────────────────────────────────────┘     │
└────────────────────────────┬────────────────────────────────────┘
                             │ 数据访问
┌────────────────────────────▼────────────────────────────────────┐
│ Core 数据模型层                                                   │
│  CADDocument / Component / Profile / Connection / Assembly       │
│  ComponentLibrary (欧标 20/30/40 系列型材参数)                    │
│  AssemblyGraph (装配关系有向图)                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 目录结构

```
Plugins/CADDesignerPlugin/
├── Package.swift
├── README.md
├── Resources/
│   ├── Catalogs/
│   │   ├── ProfileCatalog.json          # 欧标型材规格库
│   │   └── ConnectorCatalog.json        # 连接件规格库
│   ├── Component3D/
│   │   └── *.scn / *.usdz               # 预构建 3D 模型资源
│   └── Icons/
│       └── *.png / *.svg                # UI 图标
├── Sources/
│   ├── CADDesignerPlugin.swift          # 插件入口，注册到 LumiPluginRegistry
│   ├── Core/
│   │   ├── CADDocument.swift            # CAD 文档模型（Codable，支持保存/加载）
│   │   ├── ComponentLibrary.swift       # 组件库管理器
│   │   ├── AssemblyGraph.swift          # 装配关系图（节点=型材，边=连接）
│   │   └── BOMGenerator.swift           # 物料清单生成器
│   ├── Models/
│   │   ├── Component.swift              # 组件基础协议与类型
│   │   ├── Profile.swift                # 型材规格（欧标 20/30/40 系列）
│   │   ├── Connector.swift              # 连接件（角码、螺栓、滑块螺母等）
│   │   ├── Assembly.swift               # 装配体（组件集合 + 连接关系）
│   │   └── Transform3D.swift            # 3D 变换（位置、旋转、缩放）
│   ├── Services/
│   │   ├── ComponentCatalogLoader.swift # 从 JSON 加载组件目录
│   │   ├── ProjectSaveLoadService.swift # 项目保存/加载（.cadproj 格式）
│   │   ├── ScreenshotExporter.swift     # 截图/PDF 导出
│   │   └── CutOptimizer.swift           # 型材切割优化（一维 Bin Packing）
│   ├── Renderer/
│   │   ├── CADViewport.swift            # SceneKit 3D 视口
│   │   ├── ComponentRenderer.swift      # 型材/连接件 SceneKit 渲染
│   │   ├── InteractionController.swift  # 鼠标交互（旋转/平移/缩放/拖拽）
│   │   ├── HitTester.swift              # 3D 拾取（点击选择组件）
│   │   └── GridRenderer.swift           # 参考网格/坐标轴
│   ├── Tools/
│   │   ├── CADTool.swift               # 工具协议
│   │   ├── SelectTool.swift            # 选择工具
│   │   ├── PlaceComponentTool.swift    # 放置组件工具
│   │   ├── MoveTool.swift              # 移动/旋转工具
│   │   ├── ConnectTool.swift           # 连接工具
│   │   └── MeasureTool.swift           # 测量工具
│   ├── ViewModels/
│   │   ├── CADWorkspaceViewModel.swift  # 工作区视图模型
│   │   ├── ComponentPaletteVM.swift     # 组件面板视图模型
│   │   ├── BOMViewModel.swift           # BOM 视图模型
│   │   └── PropertyPanelVM.swift        # 属性面板视图模型
│   └── Views/
│       ├── CADWorkspaceView.swift       # 主工作区（SwiftUI）
│       ├── ComponentPaletteView.swift   # 组件库面板
│       ├── BOMTableView.swift           # BOM 表格
│       ├── PropertyPanelView.swift      # 属性编辑面板
│       ├── ToolBarView.swift            # 工具栏
│       └── MenuBarView.swift            # 菜单栏（文件/编辑/视图/导出）
└── Tests/
    └── CADDesignerPluginTests/
```

---

## 4. 关键技术选型

### 4.1 3D 渲染引擎

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| **SceneKit** | macOS 原生、Swift 友好、内置物理/相机控制、学习曲线低 | 不如 Metal 灵活 | ✅ **推荐** |
| **RealityKit** | 更现代、AR 集成好 | 偏重 AR/Reality，CAD 场景不太适合 | ❌ |
| **Metal (原生)** | 性能最高、完全可控 | 开发量大，需自写大量渲染管线 | ⏸️ 后期优化 |
| **OpenGL** | 成熟 | 已废弃，不推荐 | ❌ |

**结论**: MVP 使用 **SceneKit**，如后期有性能瓶颈，可针对性地用 Metal 优化渲染管线。

### 4.2 型材参数化建模

欧标铝型材的截面是标准化的，通过 **截面轮廓 + 拉伸长度** 参数化生成 3D 模型：

```
Profile 3D Model = Extrude(SectionShape, length)
```

**截面数据示例（40×40 欧标型材）**:

```json
{
  "series": "40",
  "name": "40×40 欧标型材",
  "width": 40.0,
  "height": 40.0,
  "sectionProfile": [
    {"x": 0, "y": 0},
    {"x": 5, "y": 0},
    {"x": 5, "y": 3},
    {"x": 8, "y": 3},
    {"x": 8, "y": 37},
    {"x": 5, "y": 37},
    {"x": 5, "y": 40},
    {"x": 0, "y": 40},
    {"x": 0, "y": 37},
    {"x": -3, "y": 37},
    {"x": -3, "y": 3},
    {"x": 0, "y": 3}
  ],
  "slotWidth": 8.0,
  "slotDepth": 3.0,
  "weightPerMeter": 1.45
}
```

在 SceneKit 中，通过 `SCNGeometry` 的 `SCNShape` 或自定义 `SCNGeometrySource` + `SCNGeometryElement` 实现截面拉伸。

### 4.3 欧标型材规格体系

| 系列 | 槽宽 (mm) | 常用规格 | 典型应用场景 |
|------|-----------|----------|-------------|
| **20 系列** | 6 | 20×20, 20×40, 20×60, 20×80 | 轻型框架、展示架 |
| **30 系列** | 8 | 30×30, 30×60, 30×90, 30×120 | 工作台、流水线 |
| **40 系列** | 8/10 | 40×40, 40×80, 40×120, 40×160 | 重型机架、设备框架 |

### 4.4 连接件体系

| 类型 | 名称 | 用途 |
|------|------|------|
| **角码** | 内置角码 / 外置角码 | 两型材 90° 连接 |
| **螺栓组** | T 型螺栓 + 滑块螺母 | 型材槽内紧固 |
| **端面连接板** | 端面连接件 | 型材端面对接 |
| **合页** | 型材合页 | 可开启面板 |
| **封端条** | 端盖 | 槽口美化/防护 |

### 4.5 装配关系图 (AssemblyGraph)

用**有向图**管理组件间的连接关系：

```swift
struct AssemblyGraph {
    var nodes: [ComponentNode]        // 每个节点是一个型材/连接件
    var edges: [ConnectionEdge]       // 边表示两个组件的连接关系
    
    // 连接关系：型材 A 的端面 → 型材 B 的侧面
    struct ConnectionEdge {
        let fromComponentID: UUID
        let toComponentID: UUID
        let connectionType: ConnectionType  // .rigid / .hinge / .bolt
        let fromFace: ProfileFace          // .end / .side / .top
        let toFace: ProfileFace
    }
}
```

### 4.6 物料清单 (BOM)

```swift
struct BOMItem: Identifiable {
    let id = UUID()
    let partNumber: String          // 零件号
    let description: String         // 描述，如 "40×40 欧标型材"
    let length: Double              // 切割长度 (mm)
    let quantity: Int               // 数量
    let weight: Double              // 重量 (kg)
    let material: String            // 材质，如 "6063-T5 铝合金"
}
```

### 4.7 切割优化算法

一维 Bin Packing / Cutting Stock Problem，使用 **First Fit Decreasing (FFD)** 启发式算法：

```
输入: [500mm, 800mm, 300mm, 1200mm, 600mm]  // 需求长度
原料: 6000mm 标准型材

输出:
  原料 #1: 1200 + 800 + 600 + 500 + 300 = 3400mm (余 2600mm)
  或更优分组...
```

### 4.8 项目文件格式

```
.cadproj (JSON 格式，基于 Codable)

{
  "version": "1.0",
  "name": "工作台框架",
  "created": "2025-01-15T10:00:00Z",
  "modified": "2025-01-15T11:30:00Z",
  "components": [
    {
      "id": "uuid-1",
      "type": "profile",
      "profileId": "40x40-eu",
      "length": 1200.0,
      "transform": { "x": 0, "y": 0, "z": 0, "rotX": 0, "rotY": 0, "rotZ": 0 },
      "material": "6063-T5"
    }
  ],
  "connections": [
    {
      "from": "uuid-1",
      "to": "uuid-2",
      "type": "cornerBracket",
      "fromFace": "end",
      "toFace": "side"
    }
  ]
}
```

---

## 5. SceneKit 渲染方案详设

### 5.1 视口架构

```
CADWorkspaceView (SwiftUI)
├── CADViewportSceneView (NSViewRepresentable → SCNView)
│   ├── SCNScene
│   │   ├── cameraNode (SCNNode - 轨道相机)
│   │   ├── ambientLight (SCNNode)
│   │   ├── directionalLight (SCNNode)
│   │   ├── gridNode (SCNNode - 参考网格)
│   │   ├── axisNode (SCNNode - XYZ 坐标轴)
│   │   └── assemblyNode (SCNNode - 装配体根节点)
│   │       ├── componentNode_1 (SCNNode - 型材 1)
│   │       │   ├── profileGeometry (SCNGeometry)
│   │       │   └── selectionHighlight (SCNNode)
│   │       ├── componentNode_2 (SCNNode - 型材 2)
│   │       └── connectorNode_1 (SCNNode - 连接件)
│   └── OrbitCameraController (交互)
├── ComponentPaletteView (左侧)
├── PropertyPanelView (右侧)
└── BOMTableView (底部面板)
```

### 5.2 型材几何体生成

```swift
func createProfileGeometry(profile: Profile, length: Double) -> SCNGeometry {
    // 1. 从截面轮廓创建 2D path
    let path = createSectionPath(from: profile.sectionProfile)
    
    // 2. 用 SCNShape 拉伸
    let shape = SCNShape(path: path, extrusionDepth: CGFloat(length))
    shape.firstMaterial?.diffuse.contents = NSColor.systemGray
    
    // 3. 居中调整
    shape.flatness = 0.1  // 精度控制
    
    return shape
}
```

### 5.3 交互控制

| 操作 | 手势 | 效果 |
|------|------|------|
| **旋转视角** | 鼠标左键拖拽 | 轨道旋转 |
| **平移视角** | 鼠标中键拖拽 / Option+左键 | 相机平移 |
| **缩放** | 滚轮 / 双指捏合 | 相机 zoom |
| **选择组件** | 单击 | 高亮选中 |
| **移动组件** | 拖拽选中组件 | 沿轴移动 |
| **放置组件** | 从组件面板拖入视口 | 新建组件 |

---

## 6. 与 Lumi 插件系统集成

### 6.1 插件注册

```swift
// CADDesignerPlugin.swift
import LumiPluginRegistry

@main
struct CADDesignerPlugin: Plugin {
    static let id = "com.cofficlab.lumi.cad-designer"
    static let name = "CAD 设计"
    
    func register(with registry: PluginRegistry) {
        // 注册工具命令
        registry.registerTool(CADNewProjectTool())
        registry.registerTool(CADOpenProjectTool())
        registry.registerTool(CADExportTool())
        registry.registerTool(CADPlaceComponentTool())
        
        // 注册面板
        registry.registerPanel(CADWorkspacePanel.self)
    }
}
```

### 6.2 工具定义（类比例子中的其他工具插件）

```swift
// CADNewProjectTool.swift
struct CADNewProjectTool: Tool {
    let name = "cad_new_project"
    let description = "创建新的铝型材 CAD 项目"
    
    func execute(input: ToolInput) async throws -> ToolOutput {
        let doc = CADDocument(name: input.name ?? "未命名项目")
        CADDocumentManager.shared.open(doc)
        return .success(message: "项目已创建")
    }
}
```

### 6.3 视图集成

```swift
// CADWorkspaceView.swift
struct CADWorkspaceView: View {
    @StateObject private var viewModel = CADWorkspaceViewModel()
    
    var body: some View {
        NavigationSplitView {
            ComponentPaletteView(vm: viewModel.componentPaletteVM)
        } detail: {
            VStack(spacing: 0) {
                ToolBarView(vm: viewModel.toolbarVM)
                CADViewportView(scene: viewModel.scene, interaction: viewModel.interaction)
                if viewModel.showBOM {
                    BOMTableView(vm: viewModel.bomVM)
                }
            }
        }
    }
}
```

---

## 7. 实施计划

### Phase 1: MVP 基础框架（2-3 周）

| 任务 | 内容 | 交付物 |
|------|------|--------|
| 1.1 项目骨架 | 创建 `Plugins/CADDesignerPlugin/`，Package.swift | 可编译的空插件 |
| 1.2 数据模型 | Component / Profile / Assembly 等 Core Models | 可序列化的数据模型 |
| 1.3 组件目录 | JSON 型材目录（20/30/40 系列常用规格） | ProfileCatalog.json |
| 1.4 SceneKit 视口 | 基础 3D 视口，支持轨道相机、网格、坐标轴 | 可交互的空视口 |
| 1.5 型材渲染 | 参数化型材几何体生成 + 渲染 | 视口中显示一根型材 |
| 1.6 组件面板 | 型材浏览 + 拖拽放置 | 可从面板放置型材到视口 |
| 1.7 基本交互 | 选择、移动、旋转、缩放组件 | 完整的基础交互 |

### Phase 2: 装配与 BOM（2-3 周）

| 任务 | 内容 | 交付物 |
|------|------|--------|
| 2.1 装配关系 | AssemblyGraph 实现 | 组件间连接关系管理 |
| 2.2 连接件库 | 角码/螺栓等连接件模型 | ConnectorCatalog.json |
| 2.3 智能连接 | 放置连接件时自动匹配型材接口 | 自动吸附/对齐 |
| 2.4 BOM 生成 | BOMGenerator 实现 | 物料清单表格 |
| 2.5 BOM 面板 | BOMTableView UI | 实时 BOM 展示 |
| 2.6 项目保存/加载 | .cadproj 文件格式 + 文件面板集成 | 完整的保存/打开流程 |

### Phase 3: 导出与优化（2-3 周）

| 任务 | 内容 | 交付物 |
|------|------|--------|
| 3.1 截图导出 | 视口截图 → PNG/PDF | 图片导出 |
| 3.2 切割优化 | CutOptimizer 算法 | 最优切割方案 |
| 3.3 属性面板 | 选中组件后编辑长度/位置/旋转 | 精确属性编辑 |
| 3.4 测量工具 | 两点间距离测量 | 测量标注 |
| 3.5 撤销/重做 | UndoManager 集成 | 编辑历史管理 |
| 3.6 多视图 | 四视图（透视 + 顶视 + 前视 + 侧视） | 多角度视图切换 |

### Phase 4: AI 增强与后期（2-3 周）

| 任务 | 内容 | 交付物 |
|------|------|--------|
| 4.1 AI 辅助设计 | 自然语言 → 型材框架生成 | "搭一个 1m×0.5m 工作台" |
| 4.2 STEP 导出 | 集成 OpenCASCADE / 第三方 STEP 库 | 工业标准导出 |
| 4.3 2D 工程图 | 正交投影视图 + 尺寸标注 | 简化 2D 图纸 |
| 4.4 性能优化 | 大装配体 LOD / 实例化渲染 | 流畅渲染 100+ 组件 |
| 4.5 主题适配 | LumiUI 暗色/亮色主题同步 | 主题一致性 |

---

## 8. 风险与应对

| 风险 | 等级 | 影响 | 应对策略 |
|------|------|------|---------|
| **SceneKit 精度不足** | 中 | 型材截面细节丢失 | 用自定义 `SCNGeometrySource` 替代 `SCNShape` |
| **大型装配体性能** | 中 | 100+ 组件时帧率下降 | LOD + `SCNNode` 实例化 + 按需渲染 |
| **3D 拾取精度** | 低 | 密集区域点击选错 | 射线检测 + 最近面判定 + 多选列表 |
| **OpenCASCADE 集成** | 高 | STEP 导出依赖重型 C++ 库 | MVP 不实现，后期用 WebAssembly 或独立进程 |
| **参数化截面复杂度** | 低 | 非矩形截面建模困难 | MVP 仅支持标准槽型截面，后续扩展 |
| **用户交互学习成本** | 中 | 3D 操作对新手不友好 | 提供引导教程 + 简化模式（预设模板） |

---

## 9. 参考资源

### 欧标铝型材标准
- DIN EN 12020 / DIN EN 755（铝及铝合金精密型材标准）
- 欧标 20/30/40 系列槽型截面规范
- 6063-T5 / 6061-T6 铝合金材质参数

### 技术方案参考
- Apple SceneKit Documentation
- SCNShape / SCNGeometrySource API
- 3D Math Primer for Graphics and Game Development
- First Fit Decreasing (FFD) Bin Packing Algorithm

### 竞品参考
- MayCAD (MayTec) — https://www.maytec.de/en/maycad/
- item CAD — https://www.item24.com
- 80/20 CAD Tools — https://8020.net

---

## 10. 术语表

| 术语 | 英文 | 说明 |
|------|------|------|
| 型材 | Profile / Extrusion | T 型槽铝型材主体 |
| 欧标 | European Standard | DIN 标准的型材规格体系 |
| 截面轮廓 | Section Profile | 型材横截面的 2D 形状 |
| 拉伸 | Extrude | 将 2D 截面沿长度方向拉伸为 3D |
| 连接件 | Connector | 角码、螺栓等用于连接型材的配件 |
| 装配体 | Assembly | 型材与连接件的集合及其连接关系 |
| 物料清单 | BOM (Bill of Materials) | 项目中所有零件/型材的汇总清单 |
| 切割优化 | Cut Optimization | 将需求长度组合到标准原料上，最小化浪费 |
| 轨道相机 | Orbit Camera | 围绕目标旋转的 3D 观察相机 |
| 3D 拾取 | 3D Picking / Hit Testing | 通过鼠标点击确定选中的 3D 对象 |
