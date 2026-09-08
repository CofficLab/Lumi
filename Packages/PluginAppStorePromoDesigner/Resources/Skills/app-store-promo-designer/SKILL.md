# App Store Promo Designer 工具使用指南

当用户需要创建或编辑 App Store 促销图（promotional artwork）时，使用 App Store Promo Designer 提供的 Agent 工具完成任务。

促销图是 App Store 产品页面中展示的营销图片（hero image / promo image），通过 HTML+CSS 设计，再渲染为精确尺寸的 PNG。

## 工具分组

### 任务管理
| 工具 | 用途 |
|------|------|
| `app_store_promo_list_tasks` | 列出所有促销图任务（跨 project / app 作用域） |
| `app_store_promo_create_task` | 创建促销图任务（slug、标题、App 名、设备族） |
| `app_store_promo_read_task` | 读取任务元数据、图片顺序和精确展示尺寸 |

### 图片创建与编辑
| 工具 | 用途 |
|------|------|
| `app_store_promo_create_image` | 在任务下创建一张 HTML 图片 |
| `app_store_promo_read_html` | 读取图片的完整 HTML 源码（编辑前先读取） |
| `app_store_promo_replace_html` | 用完整 HTML 文档原子替换图片 |
| `app_store_promo_patch_html` | 对 HTML 应用批量文本替换（原子操作） |
| `app_store_promo_add_image_language` | 通过复制现有语言版本添加新的本地化 |

### 资源管理
| 工具 | 用途 |
|------|------|
| `app_store_promo_import_asset` | 将本地图片复制到插件管理的资源目录 |

### 质量检查与预览
| 工具 | 用途 |
|------|------|
| `app_store_promo_preview_image` | 以 App Store 精确尺寸渲染 PNG（返回图片附件） |
| `app_store_promo_lint_task` | 校验任务中所有 HTML 图片和资源引用 |
| `app_store_promo_review_image` | 以资深设计师视角审查，返回结构化修改建议 |

### 导出
| 工具 | 用途 |
|------|------|
| `app_store_promo_export_task` | 将任务中所有图片渲染为 PNG 导出到指定目录 |

## 标准工作流

```
1. app_store_promo_create_task              → 创建任务（指定设备族）
2. app_store_promo_create_image             → 创建 HTML 图片（可带初始 HTML）
3. app_store_promo_import_asset (按需)      → 导入图片素材
4. app_store_promo_read_html                → 读取当前 HTML
5. app_store_promo_replace_html /           → 修改 HTML
   app_store_promo_patch_html
6. app_store_promo_preview_image            → 预览渲染效果
7. app_store_promo_lint_task                → 质量检查
8. app_store_promo_review_image (可选)      → 设计师审查
9. app_store_promo_add_image_language (按需)→ 添加本地化版本
10. app_store_promo_export_task             → 导出全部 PNG
```

每次修改 HTML 后，都应用 `app_store_promo_preview_image` 让 AI 看到渲染结果。

## 核心概念

### 任务（Task）
- 一个任务对应一组促销图，绑定一个设备族：`iphone` / `ipad` / `mac`
- `slug`：kebab-case 唯一标识（如 `hero-launch`）
- 每个任务下可有多张图片，每张图片支持多语言版本

### 图片（Image）
- 每张图是一个完整的 HTML 文档（`<!DOCTYPE html>` 开头）
- HTML 使用 CSS 布局，引用 `assets/` 目录下的本地图片
- 渲染时按 App Store 精确尺寸输出 PNG

### 设备族与展示尺寸
- `iphone`：iPhone 展示尺寸（如 1284×2778 等）
- `ipad`：iPad 展示尺寸
- `mac`：Mac App Store 展示尺寸
- 每种设备族有多个 `displayType` 预设，`read_task` 会返回可用尺寸

### 作用域（Scope）
- `project`：当前项目的 `.lumi` 目录
- `app`：应用数据目录
- 有打开项目时默认 `project`

## HTML 编写规范

1. **必须是完整文档**：`<!DOCTYPE html>` + `<html>` + `<head>` + `<body>`
2. **viewport 设置**：`<meta name="viewport" content="width=device-width, initial-scale=1">`
3. **引用本地资源**：使用相对路径 `assets/filename.png`
4. **使用 CSS 布局**：flexbox / grid 实现响应式排版
5. **颜色值**：使用 hex 或 rgba
6. **字体**：使用系统字体栈 `-apple-system, BlinkMacSystemFont, sans-serif`
7. **避免外部资源**：所有图片必须通过 `import_asset` 导入到本地

### HTML 模板示例
```html
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    width: 100%; height: 100%;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    color: #ffffff;
  }
  h1 { font-size: 64px; font-weight: 700; margin-bottom: 16px; }
  p { font-size: 28px; opacity: 0.9; }
  img { max-width: 60%; margin-top: 32px; }
</style>
</head>
<body>
  <h1>Your App Name</h1>
  <p>A brief tagline that sells</p>
  <img src="assets/screenshot.png" alt="App screenshot">
</body>
</html>
```

## 编辑 HTML 的方式

- **`replace_html`**：完全替换整个 HTML 文档。适合大改或重新设计。
- **`patch_html`**：批量文本替换。适合微调（改文案、调颜色、修间距）。
  - 每次最多 20 个替换操作
  - 每个操作：`{ "oldText": "...", "newText": "..." }`
  - `oldText` 必须在 HTML 中唯一存在
  - 所有替换原子执行：全部成功或全部回滚

## 常见场景

### 场景 1：从零创建 iPhone 促销图
```
app_store_promo_create_task(slug="hero-launch", title="Launch Hero", appName="MyApp", deviceFamily="iphone")
app_store_promo_create_image(taskId="hero-launch", imageId="hero-01", title="Hero Image", html="<!DOCTYPE html>...")
app_store_promo_preview_image(taskId="hero-launch", imageId="hero-01")
app_store_promo_lint_task(taskId="hero-launch")
app_store_promo_export_task(taskId="hero-launch", outputDirectory="/path/to/export")
```

### 场景 2：微调现有促销图文案
```
app_store_promo_read_html(taskId="hero-launch", imageId="hero-01")
app_store_promo_patch_html(taskId="hero-launch", imageId="hero-01", operations=[
  { "oldText": "Old headline", "newText": "New headline" },
  { "oldText": "#667eea", "newText": "#0ea5e9" }
])
app_store_promo_preview_image(taskId="hero-launch", imageId="hero-01")
```

### 场景 3：添加中文本地化
```
app_store_promo_add_image_language(taskId="hero-launch", imageId="hero-01", localeIdentifier="zh-Hans")
app_store_promo_read_html(taskId="hero-launch", imageId="hero-01", localeIdentifier="zh-Hans")
app_store_promo_replace_html(taskId="hero-launch", imageId="hero-01", localeIdentifier="zh-Hans", html="<!DOCTYPE html>...中文版本...")
app_store_promo_preview_image(taskId="hero-launch", imageId="hero-01", localeIdentifier="zh-Hans")
```

## 注意事项

- 创建图片时 `html` 参数可选，可先创建空图片再 `replace_html`。
- `replace_html` 要求传入完整 HTML 文档（含 doctype），不接受片段。
- `patch_html` 的 `oldText` 必须在 HTML 中唯一匹配，否则会失败。
- 导出前务必先 `lint_task` 确保所有图片和资源引用有效。
- `preview_image` 返回 PNG 图片附件，AI 可直接查看渲染效果。
- 素材导入后在 HTML 中用 `assets/filename.png` 引用。
