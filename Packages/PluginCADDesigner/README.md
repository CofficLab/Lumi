# PluginCADDesigner

铝型材 CAD 设计插件：把 `KitCADDesigner` 引擎包装为 `SuperPlugin`，注册 10 个 `cad_*` Agent 工具，
并通过 `ContentViewProviding` 发布 3D 编辑工作区。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## 提供什么

- 插件 ID：`com.coffic.lumi.plugin.cad-designer`，`order = 80`，`policy = .disabledByDefault`
- CAD 编辑工作区（3D 视口 / 组件库 / 属性面板 / BOM 表）
- `.cadproj` 项目保存与加载
- 10 个 Agent 工具：

| 工具 | 说明 |
|------|------|
| `cad_create_project` | 创建新项目 |
| `cad_place_profile` | 放置型材 |
| `cad_update_profile` | 更新组件长度 / 位置 / 旋转 |
| `cad_place_connector` | 放置连接件 |
| `cad_connect_components` | 建立组件间连接 |
| `cad_generate_bom` | 生成物料清单 |
| `cad_optimize_cutting` | 切割优化 |
| `cad_save_project` | 保存项目 |
| `cad_load_project` | 加载项目 |
| `cad_build_frame` | 按尺寸自动生成矩形框架 |

引擎能力（SceneKit 渲染、文档模型、切割优化）在 `KitCADDesigner`。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginCADDesigner"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginCADDesigner"]),
]
```

由宿主 `FactoryCADDesigner` 装配为 CAD Designer 专用 App。

## Testing

From this package directory:

```sh
swift test
```
