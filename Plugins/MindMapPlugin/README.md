# MindMapPlugin（思维导图）

Lumi 的原生 SwiftUI 思维导图插件。画布手动编辑 + Agent 工具驱动，二者共享同一状态，AI 改图实时反映到画布。

## 架构

复刻 `AppIconDesignerPlugin` / `CADDesignerPlugin` 范式：

```
全局聊天 → Agent 调用工具 → MindMapStore（@MainActor 单例）→ MindMapView 自动重绘
                       └─ 每次写操作落盘（JSON）
```

- **不自建对话栏**：工具经内核聚合到全局聊天（`chatVisibility: .alwaysVisible`）。
- **画布**：原生 SwiftUI（`Canvas` 绘贝塞尔连线 + 视图节点）。
- **状态共享**：`MindMapStore.shared` 单例，工具在 `MainActor.run` 内写 `@Published`。

## Agent Tools（10 个，贡献到全局聊天）

| 工具 | 作用 |
|---|---|
| `list_mind_maps` | 列出某作用域下的思维导图 |
| `create_mind_map` | 新建（根节点文本 + 标题 + 布局方向） |
| `add_child_node` | 批量给父节点加子节点（AI 扩展核心） |
| `update_node` | 改文本/备注/颜色/折叠 |
| `delete_node` | 删节点及子树（根不可删） |
| `move_node` | 重新挂载子树（带环检测） |
| `save_mind_map` | 保存并刷新 |
| `load_mind_map` | 按 id 加载到画布 |
| `export_mind_map` | 导出 Markdown / JSON |
| `import_outline` | 从 Markdown 大纲创建 |

`willSendToLLM` 会注入使用指南，引导 Agent 按 `create → add_child_node → update → export` 流程工作。

## 数据与存储

- 数据模型：扁平节点数组 + `parentId`（`MindMapNode` / `MindMap`，Codable + Sendable）。
- 布局方向：`bilateral`（双侧，默认）/ `right` / `down`。
- 双作用域：`app`（应用数据目录）/ `project`（`<project>/.lumi/mind-map/`）。
- 持久化：`<safeTitle>-<id>.json`，原子写 + ISO8601 日期。

## 布局算法

`MindMapLayoutEngine` 实现「分层整洁树」：双侧布局把根的直接子节点按索引奇偶分到左右，各自递归；垂直方向按子树高度堆叠，父节点居中于子节点跨度；水平方向按层级 × 间距展开。节点宽度按文本动态测量，`collapsed` 节点的子树不参与布局。

## 手动编辑

画布支持：拖拽平移、双指缩放（+ 工具条 ±/复位）、单击选中、双击就地编辑文本；选中节点后浮条提供「加子节点 / 加兄弟 / 折叠 / 删除」。侧栏（rail）按作用域列出文档，可切换与删除。

## 元信息

- `id`：`com.coffic.lumi.plugin.mind-map`
- `order`：81（紧邻 CADDesigner 80），`category`：`.agent`，`policy`：`.optIn`，`stage`：`.beta`

## 目录

```
Sources/
├── MindMapPlugin.swift          # 入口（LumiPlugin）
├── Hooks/WillSendToLLM.swift
├── Models/{MindMap, MindMapScope}.swift
├── Services/{Store, FileStore, Runtime, LayoutEngine, MarkdownCodec, Localization}.swift
├── Tools/{Support, SchemaSupport, *Tool}.swift
└── Views/{MindMapView, MindMapCanvas, MindMapNodeView, RailView, ToolbarTitleView, AboutView}.swift
```
