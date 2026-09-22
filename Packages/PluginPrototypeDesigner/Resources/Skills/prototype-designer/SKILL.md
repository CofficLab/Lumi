# Prototype Designer 工具使用指南

当用户需要创建、编辑或导出**产品原型图**（prototype / wireframe / mockup）时，使用 Prototype Designer 提供的 Agent 工具完成任务。

一个原型项目由**多屏**组成：每屏是一个独立的 HTML 文档，屏幕之间用 `data-prototype-link` 声明跳转。这样原型不只是静态图片，而是可点击的流程。

**核心工作方式：用聊天描述界面 → 你写 HTML → 调用 preview 看渲染结果 → 自己判断是否需要修 → 修改 → 再看。这个视觉自检回路是质量的唯一保证。**

## 工具分组

### 项目
| 工具 | 用途 |
|------|------|
| `prototype_list_projects` | 列出当前项目内的所有原型 |
| `prototype_create_project` | 创建原型（slug、标题、视觉风格、设备画板） |
| `prototype_read_project` | 读取项目结构、设备尺寸、屏幕清单与跳转拓扑 |
| `prototype_update_project` | 改标题 / 换设备画板 |
| `prototype_delete_project` | 删除原型（不可撤销） |

### 屏幕
| 工具 | 用途 |
|------|------|
| `prototype_add_screen` | 新增一屏（不传 html 时按风格生成模板） |
| `prototype_duplicate_screen` | 复制一屏做变体 |
| `prototype_delete_screen` | 删除一屏 |
| `prototype_reorder_screens` | 重排屏幕顺序（即流程阅读顺序） |
| `prototype_set_start_screen` | 指定起始屏 |

### HTML 编辑
| 工具 | 用途 |
|------|------|
| `prototype_read_html` | 读取一屏完整 HTML（**编辑前必须先读**） |
| `prototype_replace_html` | 用完整 HTML 文档原子替换（大幅重写用） |
| `prototype_patch_html` | 批量精确文本替换（局部修改用，≤20 条） |

### 预览 / 资源 / 交付
| 工具 | 用途 |
|------|------|
| `prototype_preview_screen` | 按设备尺寸渲染一屏，返回 PNG **附件**供你视觉检查 |
| `prototype_import_asset` | 把本地图片复制进项目共享素材目录 |
| `prototype_lint` | 校验全部屏幕的 HTML、资源引用与跳转目标 |
| `prototype_export` | 把每一屏渲染成 PNG 导出到指定目录 |

## 标准工作流

```
1. prototype_create_project(style, deviceKind)   → 定画板与风格
2. prototype_add_screen(项目首屏)                 → 先做起始屏
3. prototype_replace_html / patch_html           → 写/改 HTML
4. prototype_preview_screen                      → 看渲染结果（必做）
   ↳ 不满意就回到 3，反复迭代直到画面成立
5. prototype_add_screen(后续屏)                   → 逐屏添加
   ↳ 每加一屏都重复 3-4
6. 在 HTML 里写 data-prototype-link 连接屏幕       → 形成流程
7. prototype_set_start_screen (按需)              → 指定入口屏
8. prototype_lint                                → 全项目校验
9. prototype_export                              → 导出 PNG
```

**每次改完 HTML 都必须调用 `prototype_preview_screen`。** 不看渲染结果就继续改，等于盲写。

## 核心概念

### 设备画板（Device）
项目级设置，所有屏幕共用同一画布。尺寸以**逻辑点（CSS px）**计，导出像素 = 逻辑尺寸 × scale。

| deviceKind | 逻辑尺寸 | 导出像素 |
|---|---|---|
| `iPhone15Pro` | 393×852 | 1179×2556 |
| `iPhone15ProMax` | 430×932 | 1290×2796 |
| `iPhoneSE` | 375×667 | 750×1334 |
| `iPadPro11` | 834×1194 | 1668×2388 |
| `iPadPro129` | 1024×1366 | 2048×2732 |
| `desktop` | 1440×900 | 2880×1800 |
| `custom` | 需传 deviceWidth/deviceHeight | 逻辑尺寸 × deviceScale |

用户没指定设备时，移动端 App 默认 `iPhone15Pro`。

### 视觉风格（Style）
- `wireframe`：低保真线框图。灰阶、虚线占位框，强调信息层级与流程，**用于验证结构**。
- `hiFi`：高保真。带品牌色、圆角与真实排版，**用于评审视觉与文案**。

用户说"线框图 / 草图 / 低保真"用 `wireframe`；说"高保真 / 效果图 / 接近成品"用 `hiFi`。不确定时先 `wireframe`——改结构比改视觉便宜。

### 屏幕（Screen）
- `screenId` 是 kebab-case slug（如 `01-home`、`02-detail`），**它就是跳转目标的名字**。
- 建议用 `序号-语义` 命名，让文件系统上的导出结果也读得懂流程。
- 第一屏自动成为起始屏。

### 存储
- 全部内容存储在当前项目的 `.lumi/prototype/tasks/<项目 slug>/`。
- 每屏一个目录：`<screenId>/index.html`。
- 图片素材统一放在项目级 `assets/`，屏幕用 `../assets/文件名` 引用。
- **未打开项目时工具不可用**，会提示先打开项目。

## HTML 编写规范

### 硬性要求（linter 会拒绝）

1. **必须是完整文档**：`<!DOCTYPE html>` + `<html>` + `<head>` + `<body>` + `</html>`。
   绝对不能只传一个片段。
2. **必须声明 viewport**：`<meta name="viewport" content="width=device-width, initial-scale=1">`
3. **禁止 `<script>`**：跳转用 `data-prototype-link` 声明，宿主会注入导航脚本。写了 script 会直接报错。
4. **禁止 `<iframe>`**
5. **禁止远程资源**：不能出现 `http://` / `https://`。图片必须先 `prototype_import_asset`。
6. **禁止 CSS `@import`**
7. **资源路径不能逃逸项目目录**：不能以 `/` 开头（绝对路径一律拒绝）。相对路径允许用 `../` 回到项目根引用共享素材——`../assets/x.png` 是**正确写法**，但 `../../../../etc/passwd` 这类逃出项目的路径会被拒绝。
8. **引用本地图片必须真实存在**，否则报 `missing_asset`。

### 强烈建议

9. **根元素设 `overflow: hidden`**：设备边框内不应出现滚动条。
10. **声明不透明背景**：否则导出的 PNG 是透明的。
11. **给主要区块和可能单独讨论的交互控件加 `data-block` 与 `data-block-label`**：这样用户在预览里右键元素时，既能选择具体控件，也能选择所属区块。`data-block` 在同一屏内必须唯一，且不能为空。
    ```html
    <section data-block="header" data-block-label="顶部栏"> ... </section>
    ```
12. **动效可用但会警告**：`animation` / `transition` 在导出时会被强制关闭，只当装饰用，不要承载语义。

### 跳转的写法

在需要跳转的控件上声明目标屏 slug：

```html
<button data-prototype-link="02-detail" data-prototype-label="进入详情">查看详情</button>
```

- `data-prototype-link` 的值**必须是项目里真实存在的 screenId**，否则报 `unknown_link_target`（这是 error，会阻断保存）。
- `data-prototype-label` 可选，用于在工具结果里显示这个跳转的语义。
- 不要写 `<a href="...">` 来做跳转——`href` 会被当作资源路径校验。
- 一屏没有声明任何跳转时会给 warning（`no_navigation`），提示这屏点不通。

### 基础骨架

```html
<!DOCTYPE html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<title>首页</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body { width: 100%; height: 100%; overflow: hidden; }
  body {
    display: flex; flex-direction: column;
    background: #f4f5f7; color: #2b2f36;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
  }
  .content { flex: 1; padding: 16px; display: flex; flex-direction: column; gap: 12px; overflow: hidden; }
</style>
</head>
<body>
  <header data-block="header" data-block-label="顶部栏"> ... </header>
  <main class="content">
    <section data-block="hero" data-block-label="主视觉"> ... </section>
  </main>
  <button data-block="primary-action" data-block-label="主操作"
          data-prototype-link="02-detail" data-prototype-label="进入详情">查看详情</button>
</body>
</html>
```

## 设计原则

### 布局
- 用 **flexbox** 纵向排布主区块，`flex: 1` 让内容区占满剩余高度。
- 设备高度固定且不滚动，所以**内容必须放得下**。宁可少放几项，也不要溢出被裁掉。
- 尺寸用相对单位（`%`、`flex`）或固定 px 都行，但**别用 `vmin`/`vmax` 猜**——预览和导出按逻辑尺寸渲染，相对单位是可靠的。

### 信息层级
- 一屏只表达**一个主要任务**。如果需要两件事，那就是两屏。
- 视觉权重从大到小：主操作 > 主要内容 > 辅助信息 > 装饰。

### 低保真线框图的具体做法
- 灰阶：`#f4f5f7` 底 / `#ffffff` 面 / `#e6e9ef` 占位 / `#2b2f36` 文字。
- 占位元素用虚线边框 + 灰底：`border: 1px dashed #b6bcc7;`。
- 文字线用细圆角矩形：`height: 8px; border-radius: 4px; background: #e6e9ef;`。
- 敢写真实文案（"结账"、"添加商品"），比 Lorem ipsum 更有助于评审。

### 文案
- 用用户的语言。用户说中文就写中文，别混英文占位。
- 按钮写**动词短语**："开始结账"、"保存草稿"，不要写"提交"这种模糊词。

## 常见错误

| 现象 | 原因 | 修正 |
|---|---|---|
| `script_forbidden` | HTML 里有 `<script>` | 删掉，用 `data-prototype-link` |
| `remote_resource` | 引用了外部 URL | 先 `prototype_import_asset`，再用相对路径 |
| `malformed` / `incomplete_document` | 传了片段，不是完整文档 | 补齐 `<!DOCTYPE html>` 等骨架 |
| `unknown_link_target` | `data-prototype-link` 指向不存在的屏 | 先 `prototype_add_screen` 建那屏，或改成已有 screenId |
| `missing_asset` | 引用了不存在的图片 | 先 `prototype_import_asset` |
| `unsafe_asset_path` | 路径以 `/` 开头，或逃出了项目目录 | 共享素材用 `../assets/文件名` |
| `escaped_markup` | HTML 里出现被转义的 `&lt;script&gt;` | 确认没把真正的标签写成转义文本 |
| `patchTextMissing` | `oldText` 在 HTML 里找不到 | 先 `prototype_read_html` 拿到真实文本（注意空格与换行） |
| `patchTextNotUnique` | `oldText` 出现多次 | 扩大 `oldText` 范围让它唯一 |
| 预览里内容被裁 | 内容超过设备高度 | 减少条目或缩小间距 |

## 注意事项

- 收到“原型元素引用（v1）”时，引用描述的是用户点击时的快照。修改前仍须调用 `prototype_read_html` 读取当前屏幕，优先用唯一的 `data-block` 定位，再用 selector、元素 HTML 和区块上下文消歧。
- 只修改引用元素或其最小必要上下文；不要因为收到局部引用而重写整屏。
- 如果引用注明 HTML 已截断，绝不能直接依据片段修改；必须读取完整 HTML。
- 引用可能来自较早的对话轮次。若屏幕后来被修改过，以最新 `prototype_read_html` 结果为准，不要假设引用中的 HTML 仍是当前内容。
- **改 HTML 前先 `prototype_read_html`**。patch 要求 `oldText` 完全一致，凭记忆写必然失败。
- **`patch_html` 是原子的**：任一条替换失败，整批都不写入。所以不必担心半改状态。
- **换设备画板后要重新预览每一屏**：CSS 按原尺寸写的内容在新画布上可能溢出。
- **删除屏幕会让其他屏的跳转悬空**，删完记得 `prototype_lint` 查一下。
- **导出前先 lint**，导出的工具本身也会校验，校验不过会直接中断。
