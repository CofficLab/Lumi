# App Icon Designer 工具使用指南

当用户需要设计、编辑或导出应用图标时，使用 App Icon Designer 提供的 Agent 工具完成任务。

## 工具分组

### 文档管理
| 工具 | 用途 |
|------|------|
| `list_icon_documents` | 列出所有图标文档（跨 project / app 作用域） |
| `create_icon_document` | 创建空白矢量文档（默认 1024×1024） |
| `apply_icon_preset` | 从内置预设快速创建文档 |
| `load_icon_document` | 从 JSON 文件导入文档 |
| `save_icon_document` | 保存文档为 JSON 文件 |

### 形状与图层
| 工具 | 用途 |
|------|------|
| `add_icon_shape` | 添加矢量图层：rectangle / circle / capsule / triangle / line / symbol / text |
| `update_icon_shape` | 修改图层的几何属性（位置、尺寸、圆角、文字、SF Symbol） |
| `update_icon_layer` | 修改图层的样式属性（颜色、透明度、位移、缩放、旋转、阴影、模糊） |
| `set_icon_background` | 设置背景：纯色 / 线性渐变 / 径向渐变 |

### 质量检查与预览
| 工具 | 用途 |
|------|------|
| `preview_icon` | 渲染 PNG 预览图（返回图片附件供视觉检查） |
| `lint_icon_document` | 检查导出质量问题（溢出、对比度、安全边距等） |
| `review_icon` | 以资深设计师视角审查图标，返回结构化修改建议 |

### 导出
| 工具 | 用途 |
|------|------|
| `export_icon_svg` | 导出为 SVG 矢量文件 |
| `export_app_icon` | 导出为 Xcode 26 AppIcon.icon（支持 macOS 15+） |
| `register_app_icon_artifact` | 将外部图片注册为图标候选项 |

## 标准工作流

```
1. create_icon_document / apply_icon_preset    → 创建文档
2. set_icon_background                          → 设置背景
3. add_icon_shape (多次)                        → 逐层添加形状
4. update_icon_shape / update_icon_layer (按需) → 微调几何与样式
5. preview_icon                                 → 预览效果
6. lint_icon_document                           → 质量检查
7. review_icon (可选)                           → 设计师审查
8. export_app_icon / export_icon_svg            → 导出成品
```

每次完成一轮修改后，都应用 `preview_icon` 让 AI 自己看到渲染结果再决定下一步。

## 坐标系统

- 默认画布 **1024 × 1024**，原点左上角
- 所有坐标单位为设计稿像素（非 pt）
- 安全边距：主要内容距边缘至少 **96px**（约 10%），避免被系统 squircle 裁切
- 视觉重心建议略高于几何中心（约 48-52% 高度处）

## 形状参数速查

### rectangle
`x, y, width, height, cornerRadius`

### circle
`cx, cy, radius`

### capsule
`x, y, width, height`

### triangle
`x, y, width, height`

### symbol（SF Symbol）
`symbolName, x, y, size, weight`
- 支持所有 SF Symbol 名称
- weight: ultralight / thin / light / regular / medium / semibold / bold / heavy / black

### text
`text, x, y, size, weight`

### line
`x1, y1, x2, y2`

## 样式属性

所有形状支持：
- `fill` — 填充色（#RRGGBB 或 #RRGGBBAA）
- `stroke` + `strokeWidth` — 描边
- `opacity` — 透明度 0~1
- `shadowColor` + `shadowRadius` + `shadowX` + `shadowY` — 阴影
- `blurRadius` — 模糊

## 背景类型

- 纯色：`type=color`, `color=#RRGGBB`
- 线性渐变：`type=linearGradient`, `colors=[#c1, #c2, ...]`
- 径向渐变：`type=radialGradient`, `colors=[#c1, #c2, ...]`

## 设计原则

1. **轮廓识别性** — 在 29pt 小尺寸下仍能一眼识别主体形状
2. **视觉平衡** — 构图居中稳定，避免重心偏移；内容不要挤满边缘
3. **对比度** — 前景与背景有足够对比，注意深色/浅色模式下的可读性
4. **简洁克制** — 避免过多细节和图层，图标需要在小尺寸下保持清晰
5. **平台适配** — 遵循 Apple 图标风格：squircle 友好、不过度装饰、避免小字

## 常见场景

### 场景 1：从零设计一个图标
```
create_icon_document(title="My App Icon", background="#1a1a2e")
add_icon_shape(shape="circle", cx=512, cy=512, radius=360, fill="#e94560")
add_icon_shape(shape="symbol", symbolName="bolt.fill", x=512, y=512, size=400, fill="#ffffff", weight="bold")
preview_icon()
lint_icon_document()
export_app_icon(outputDirectory="/path/to/project/Assets.xcassets")
```

### 场景 2：从预设快速开始
```
apply_icon_preset(presetId="gradient-glass")
update_icon_layer(layerId="<id>", fill="#0ea5e9")
preview_icon()
export_icon_svg(outputPath="/tmp/icon.svg")
```

### 场景 3：审查并优化现有图标
```
list_icon_documents()
preview_icon(documentId="<id>")
review_icon(documentId="<id>")
# 根据审查建议修改
update_icon_shape(layerId="<id>", radius=128)
preview_icon()
```

## 注意事项

- `update_icon_shape` 修改几何属性（位置、尺寸），`update_icon_layer` 修改样式属性（颜色、阴影、旋转）。不要混淆。
- 图层顺序由添加顺序决定：后添加的在上层。
- 导出 `export_app_icon` 生成 Xcode 26 格式的 `.icon` 目录，适用于 macOS 15+。
- 每次修改后建议 `preview_icon` 自检，避免累积错误。
- `scope` 参数控制存储位置：`project`（当前项目）或 `app`（应用数据目录）。有打开项目时默认 `project`。
