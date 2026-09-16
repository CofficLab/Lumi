# Booklet Maker 工具使用指南

当用户需要把 PDF 做成可打印装订的小册子（折页 / 骑马钉），或按页范围拆分 PDF 时，
使用 Booklet Maker 提供的 Agent 工具完成任务。

小册子（booklet）指：把若干张纸**双面打印**后沿中线**折叠**、在折缝处**装订**成册。
为此源 PDF 的页面必须重新排序（拼版 / imposition），使折叠后页序正确读通。

## 工具分组

| 工具 | 用途 | 风险 |
|------|------|------|
| `pdf_inspect` | 读取 PDF 页数、页面尺寸、加密状态，并给出拼版计划（纸张数与逐面页序） | 低 |
| `booklet_make` | 把 PDF 拼版为可打印的小册子 PDF | 中（`overwrite=true` 为高） |
| `pdf_split` | 按切点把 PDF 拆成多个文件 | 中（`overwrite=true` 为高） |
| `booklet_preview` | 渲染前几个印刷面为 PNG 附件，供视觉确认 | 低 |

## 标准工作流

```
1. pdf_inspect(path)                       → 确认页数/尺寸，查看拼版计划
2. booklet_preview(path, …)                → 视觉确认页序与留白（可选但推荐）
3. booklet_make(sourcePath, outputPath, …) → 生成小册子 PDF
```

拆分流程：
```
1. pdf_inspect(path)                       → 确认页数，确定切点合法
2. pdf_split(sourcePath, outputDirectory, cutPoints=[20, 50])
```

每次生成前都应 `pdf_inspect` 确认页数，避免切点越界或对空白页拼版。

## 核心概念

### 拼版（imposition）
源页面被重排到「印刷面」的左右两个格子中。以 `bookletFold` 为例，8 页的源文档：

| 物理纸张 | 正面 | 背面 |
|---------|------|------|
| Sheet 1 | 8 \| 1 | 2 \| 7 |
| Sheet 2 | 6 \| 3 | 4 \| 5 |

双面打印后沿中线折叠，页序即为 1→2→3…→8。

### 补白（padding）
`bookletFold` 需要 4 的倍数个页面槽位：页数不足时自动补空白页
（`padBlankPage`，默认 `true`）。**页面槽位用 0 表示留白格**。

### 输出纸张
小册子的输出是**横向纸张**，左右两个格子各放一个缩放后的源页面。
常用映射：A4 横向 = 2×A5 页面。

## 参数速查

### 拼版参数（`pdf_inspect` / `booklet_make` / `booklet_preview` 共用）

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `paper` | string | `a4` | 输出纸张：`a4` / `a5` / `letter` |
| `layout` | string | `bookletFold` | `bookletFold`（折页装订）或 `simplePair`（按文档顺序成对） |
| `marginMM` | number | `5` | 四周外边距（毫米） |
| `gutterMM` | number | `5` | 左右格子之间的中缝（毫米） |
| `padBlankPage` | boolean | `true` | 是否补空白页以适配布局 |
| `addCutMarks` | boolean | `true` | 是否在格子四角画裁切标记 |

### 布局模式

- **`bookletFold`** — 折页装订。页序被重排，双面打印 → 折叠 → 装订即得正确小册子。
- **`simplePair`** — 简单成对。第 `2k` 页与 `2k+1` 页左右并排，保持文档顺序。
  适合只打单面、之后手动翻面再打的场景。

### `pdf_split` 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| `sourcePath` | ✓ | 源 PDF 绝对路径 |
| `outputDirectory` | ✓ | 输出目录（不存在则创建） |
| `cutPoints` | ✓ | 切点数组，1-based 页号，**表示「切在第几页之后」** |
| `baseName` | | 输出文件名主干，默认取源文件名 |
| `overwrite` | | 是否覆盖已存在的输出，默认 `false` |

`cutPoints=[20, 50]` 处理 100 页文档 → 三段：1–20、21–50、51–100。
切点必须满足 `1 ≤ cutPoint < 页数`，否则工具报错。

## 注意事项

- **路径必须是绝对路径**；相对路径会被当作相对于进程当前目录。
- `booklet_make` 默认不覆盖已有文件；需显式传 `overwrite=true`（高风险）。
- `booklet_make` 会原子写入输出，失败时不会留下半成品；覆盖时会先删除旧文件。
- 源 PDF 若加密或页面尺寸为 0，`pdf_inspect` / `booklet_make` 会直接报错。
- `booklet_preview` 的临时文件写在插件数据目录，结果只以 PNG 附件返回，不落盘到用户目录。
- 打印提示：**双面、沿短边翻转（flip on short edge）**，与工具返回的说明一致。
- 用户界面里的「拆分 PDF / 小册子」面板与本组工具行为一致，可相互印证。

## 常见场景

### 场景 1：把讲稿 PDF 做成 A5 骑马钉小册子
```
pdf_inspect(path="/Users/me/slides.pdf")
booklet_preview(path="/Users/me/slides.pdf", maxSides=4)
booklet_make(
  sourcePath="/Users/me/slides.pdf",
  outputPath="/Users/me/slides-booklet.pdf",
  paper="a4",
  layout="bookletFold"
)
```

### 场景 2：章节拆分后再分别装订
```
pdf_inspect(path="/Users/me/book.pdf")
pdf_split(
  sourcePath="/Users/me/book.pdf",
  outputDirectory="/Users/me/chapters",
  cutPoints=[20, 50, 80]
)
booklet_make(
  sourcePath="/Users/me/chapters/book-part-1.pdf",
  outputPath="/Users/me/book-part-1-booklet.pdf"
)
```

### 场景 3：调整边距后重新预览
```
booklet_preview(path="/Users/me/report.pdf", paper="letter", marginMM=10, gutterMM=8)
booklet_make(
  sourcePath="/Users/me/report.pdf",
  outputPath="/Users/me/report-booklet.pdf",
  paper="letter",
  marginMM=10,
  gutterMM=8,
  addCutMarks=false
)
```
