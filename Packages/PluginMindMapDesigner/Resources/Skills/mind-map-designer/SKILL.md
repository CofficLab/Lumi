# Mind Map Designer 工具使用指南

当用户需要创建、编辑或导出思维导图时，使用 Mind Map Designer 提供的 Agent 工具完成任务。

## 工具分组

### 文档管理
| 工具 | 用途 |
|------|------|
| `list_mind_maps` | 列出所有思维导图（跨 project / app 作用域） |
| `create_mind_map` | 创建新思维导图（含根节点、标题、布局方向） |
| `load_mind_map` | 从 JSON 文件导入思维导图 |
| `save_mind_map` | 保存思维导图为 JSON 文件 |

### 节点编辑
| 工具 | 用途 |
|------|------|
| `add_child_node` | 给指定父节点批量添加子节点（核心扩展工具） |
| `update_node` | 更新节点的文本、备注、颜色或折叠状态 |
| `delete_node` | 删除节点及其整个子树（根节点不可删除） |
| `move_node` | 将节点（含子树）移到新的父节点下（自动防环） |

### 导入与导出
| 工具 | 用途 |
|------|------|
| `import_outline` | 从 Markdown 大纲文本创建思维导图 |
| `export_mind_map` | 导出为 Markdown 大纲或 JSON 格式 |

## 标准工作流

```
1. create_mind_map / import_outline         → 创建思维导图
2. add_child_node (多次，按分支扩展)        → 逐层添加节点
3. update_node (按需)                       → 调整文本、颜色、备注
4. move_node (按需)                         → 重组结构
5. delete_node (按需)                       → 删除不需要的分支
6. export_mind_map                          → 导出成品
```

每次添加较多节点后，建议检查返回的节点 ID，后续操作需要用到。

## 布局方向

| 方向 | 说明 | 适用场景 |
|------|------|----------|
| `bilateral` | 根节点居中，子节点左右展开（默认） | 经典思维导图、头脑风暴 |
| `right` | 仅向右展开 | 流程图式思维、时间线 |
| `down` | 向下展开 | 组织架构图、层级结构 |

## 节点模型

每个节点包含：
- `id` — 唯一标识（UUID，创建时自动生成）
- `parentId` — 父节点 ID（根节点为 null）
- `text` — 显示文本
- `note` — 可选备注（不在画布上显示，导出时可见）
- `color` — 可选填充色（hex，如 `#38bdf8`）
- `collapsed` — 是否折叠子树

## 编辑策略

### 批量添加子节点
```
add_child_node(parentId="<root-id>", texts: ["分支A", "分支B", "分支C"])
```
- 一次可添加多个同级兄弟节点
- 返回每个新节点的 ID，后续可用于继续扩展
- 可选指定 `color` 统一设置颜色

### 从大纲快速创建
```
import_outline(outline: """
# 项目规划
- 需求分析
  - 用户调研
  - 竞品分析
- 设计阶段
  - 信息架构
  - UI 设计
- 开发实施
  - 前端开发
  - 后端开发
""")
```
- Markdown 缩进列表自动映射为树结构
- 第一行标题成为根节点
- 比逐个 `add_child_node` 更高效

### 调整节点内容
```
update_node(nodeId="<id>", text="新文本", color="#f59e0b")
```
- 只传需要修改的字段，未传的不变
- `collapsed: true` 可折叠大子树，减少画布拥挤

### 重组结构
```
move_node(nodeId="<id>", toParentId="<new-parent-id>")
```
- 自动拒绝会产生环的操作
- 子树跟随被移动节点一起迁移

## 常见场景

### 场景 1：头脑风暴
```
create_mind_map(rootText="产品方向", layoutDirection="bilateral")
add_child_node(parentId="<root-id>", texts: ["用户增长", "商业化", "技术升级"])
add_child_node(parentId="<增长-id>", texts: ["社交分享", "SEO优化", "内容营销"])
add_child_node(parentId="<商业化-id>", texts: ["订阅制", "广告", "增值服务"])
```

### 场景 2：从大纲导入已有结构
```
import_outline(outline: "# 知识体系\n- 前端\n  - Swift\n  - SwiftUI\n- 后端\n  - Node.js\n  - Python")
export_mind_map(format="markdown")
```

### 场景 3：组织架构图
```
create_mind_map(rootText="CEO", layoutDirection="down")
add_child_node(parentId="<root-id>", texts: ["CTO", "CFO", "COO"])
add_child_node(parentId="<CTO-id>", texts: ["iOS 团队", "后端团队", "基础架构"])
```

## 作用域

- `project` — 存储在打开项目的 `.agent/mind-maps/` 目录
- `app` — 存储在应用数据目录
- 有打开项目时默认 `project`，无项目时默认 `app`

## 注意事项

- `add_child_node` 返回的新节点 ID 是后续 `update_node`、`delete_node`、`move_node` 的必需参数，务必记录。
- 根节点不可删除（`delete_node` 会拒绝）。
- `move_node` 不能将节点移到自己的后代节点下（防环）。
- `import_outline` 的 Markdown 缩进必须一致（使用 2 空格或 tab），否则层级解析可能出错。
- 导出 `markdown` 格式适合粘贴到文档或笔记应用；`json` 格式适合备份和跨设备同步。
- 画布自动布局：添加/删除/移动节点后无需手动重排。
