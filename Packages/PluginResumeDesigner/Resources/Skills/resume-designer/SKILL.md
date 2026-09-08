# Resume Designer 工具使用指南

当用户需要创建、编辑或导出个人简历时，使用 Resume Designer 提供的 Agent 工具完成任务。

## 工具分组

### 文档管理
| 工具 | 用途 |
|------|------|
| `resume_list` | 列出所有简历文档 |
| `resume_create` | 从模板创建新简历（paper: a4/letter，template: classic/modern/minimal/blank） |
| `resume_read` | 读取简历元数据（标题、纸张、模板、更新时间） |
| `resume_read_html` | 读取简历完整 HTML 内容 |

### HTML 编辑
| 工具 | 用途 |
|------|------|
| `resume_replace_html` | 整体替换简历 HTML（适合大幅度重写） |
| `resume_patch_html` | 批量精确文本替换（每次最多 20 条 oldText→newText，适合局部修改） |

### 资源与媒体
| 工具 | 用途 |
|------|------|
| `resume_import_asset` | 将本地图片（证件照等）复制到简历资源目录 |

### 质量检查与预览
| 工具 | 用途 |
|------|------|
| `resume_lint` | 静态校验 + 运行时分页测量（页数、纸张尺寸匹配、内容溢出） |
| `resume_preview_page` | 渲染指定页为 PNG 图片附件，供视觉检查 |

### 导出
| 工具 | 用途 |
|------|------|
| `resume_export` | 导出为矢量 PDF（可打印、文字可选中）和/或 PNG 页面（可控 DPI） |

## 标准工作流

```
1. resume_create(paper, template)             → 从模板创建简历
2. resume_read_html                           → 查看当前 HTML 结构
3. resume_replace_html / resume_patch_html    → 编辑内容
4. resume_import_asset (按需)                 → 导入照片等资源
5. resume_lint                                → 校验 HTML + 分页检查
6. resume_preview_page                        → 渲染预览自检
7. resume_export(format, outputDirectory)     → 导出成品
```

每次完成一轮 HTML 修改后，都应 `resume_lint` 检查有效性，再 `resume_preview_page` 视觉确认。

## 纸张规格

- **a4** — 210 × 297 mm（国际标准）
- **letter** — 8.5 × 11 in（北美标准）

HTML 中 `@page` 和根容器尺寸必须严格匹配纸张规格，否则 lint 报错。

## 模板类型

| 模板 | 特点 |
|------|------|
| `classic` | 传统单栏布局，适合保守行业 |
| `modern` | 双栏布局，左侧技能/联系方式，右侧经历 |
| `minimal` | 极简单栏，无装饰线条 |
| `blank` | 空白 HTML 骨架，完全自定义设计 |

## HTML 编写规范

1. **确定性排版** — 不使用 JavaScript、不依赖外部字体/CDN；所有样式内联或 `<style>` 内嵌
2. **纸张适配** — 根容器 `width` 和 `height` 必须等于纸张 CSS 尺寸
3. **分页控制** — 内容超出单页时使用 `page-break-before` / `page-break-inside: avoid` 控制分页
4. **图片引用** — 通过 `resume_import_asset` 导入后用相对路径 `assets/xxx.png` 引用
5. **字体安全** — 仅使用系统字体栈（如 `-apple-system, "Helvetica Neue", Arial, sans-serif`）或已导入的本地字体

## 编辑策略

### 小范围修改 → `resume_patch_html`
```
resume_patch_html(operations: [
  { oldText: "旧手机号", newText: "新手机号" },
  { oldText: "旧公司名", newText: "新公司名" }
])
```
- 每条替换要求 `oldText` 在 HTML 中**唯一出现**
- 最多 20 条操作/次
- 修改后自动校验

### 大范围重写 → `resume_replace_html`
```
resume_replace_html(html: "<!DOCTYPE html>...完整 HTML...")
```
- 替换前务必 `resume_read_html` 获取当前内容
- 新 HTML 必须是完整文档（含 `<!DOCTYPE html>`）

## 导出格式

| 格式 | 说明 |
|------|------|
| `pdf` | 矢量 PDF，文字可选中，适合打印和邮件附件（默认） |
| `png` | 按页渲染 PNG，默认 300 DPI（印刷质量） |
| `both` | 同时导出 PDF 和 PNG |

导出 DPI 选项：72（屏幕）/ 150（草稿）/ 300（印刷）/ 600（高精度）

## 常见场景

### 场景 1：从零创建简历
```
resume_create(slug="john-doe", title="John Doe", paper="a4", template="modern")
resume_read_html(resumeId="john-doe")
# 根据模板结构编辑内容
resume_replace_html(resumeId="john-doe", html="...")
resume_lint(resumeId="john-doe")
resume_preview_page(resumeId="john-doe")
resume_export(resumeId="john-doe", format="pdf", outputDirectory="/Users/john/Desktop")
```

### 场景 2：更新联系信息
```
resume_read_html(resumeId="john-doe")
resume_patch_html(resumeId="john-doe", operations: [
  { oldText: "old@email.com", newText: "new@email.com" }
])
resume_lint(resumeId="john-doe")
```

### 场景 3：添加证件照
```
resume_import_asset(resumeId="john-doe", sourcePath="/Users/john/photo.jpg")
resume_read_html(resumeId="john-doe")
resume_patch_html(resumeId="john-doe", operations: [
  { oldText: "<!-- photo placeholder -->", newText: "<img src=\"assets/photo.jpg\" />" }
])
resume_preview_page(resumeId="john-doe")
```

## 注意事项

- 简历仅存储在应用数据目录（app 作用域），不支持项目内存储。
- `resume_export` 的 `outputDirectory` 必须由用户明确指定，不可自行选择路径。
- `resume_lint` 在导出前**必须**通过，否则导出会失败。
- `resume_patch_html` 的 `oldText` 必须在 HTML 中唯一出现，否则操作会被拒绝。
- 每次修改后建议 `resume_preview_page` 自检，避免累积排版错误。
