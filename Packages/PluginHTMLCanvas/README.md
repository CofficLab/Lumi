# PluginHTMLCanvas

HTML 画布插件：让 LLM 通过调用工具，在聊天消息区渲染一张 **HTML 界面卡片**。

## 它解决什么问题

聊天消息区默认只能渲染 Markdown 文本与工具调用卡片。当 LLM 需要给用户
「看」点什么——一张图表、一个示意图、一个报表版式、一段交互原型——
它只能把 HTML 塞进代码块，用户看到的是源码，不是界面。

本插件提供了这条缺失的通路：

```
LLM 调用 show_html 工具
        ↓
插件把 HTML 落盘成文件，并预渲染一张 PNG 快照
        ↓
插件插入一条带 renderKind = "html-canvas" 的时间线消息
        ↓
消息渲染器命中 → 渲染一张「标题 + 界面预览」的卡片
        ↓
用户在聊天区直接看到界面
```

## 结构

| 路径 | 内容 |
|------|------|
| `Sources/PluginHTMLCanvas/Models/` | 卡片载荷模型与时间线消息构造 |
| `Sources/PluginHTMLCanvas/Tools/` | LLM 可调用的 `show_html` 工具 |
| `Sources/PluginHTMLCanvas/Services/` | 消息桥、HTML 落盘与快照渲染 |
| `Sources/PluginHTMLCanvas/Views/` | 卡片视图与消息渲染器 |
| `Resources/Localizable.xcstrings` | 多语言文案 |

## 工具

`show_html`

| 参数 | 必填 | 说明 |
|------|:----:|------|
| `html` | ✅ | 完整 HTML 文档（含 `<!DOCTYPE html>` / `<html>` / `<head>` / `<body>`），CSS 与 JS 需内联 |
| `title` | ⬚ | 卡片标题，缺省用「HTML Preview」 |
| `width` | ⬚ | 设计画布宽度（CSS 逻辑像素），缺省 800，钳制到 200–4096 |
| `height` | ⬚ | 设计画布高度（CSS 逻辑像素），缺省 600，钳制到 200–4096 |

## 两个关键设计决策

### HTML 落盘，不进消息 metadata

`Message.metadata` 的类型是 `[String: String]`，而 LLM 画出来的界面可能有几十 KB。
把整份 HTML 塞进 metadata 会撑爆消息表，也让每轮上下文的解码成本变高。

因此载荷里只记**文件位置**：

- `htmlPath` — 落盘的 HTML 源文件，位于插件数据目录 `canvases/` 下；
- `snapshotPath` — 预渲染的 PNG 快照。

### 默认渲染 PNG 快照，而不是活的 WKWebView

消息列表是 `List`，行内容会被惰性物化。若直接嵌 `WKWebView`：

- WebView 会抢走外层 `List` 的滚轮事件，用户滚不动聊天记录；
- 每次滚出视口再滚回来都会重建一个 WKWebView（一次完整 HTML 解析）。

因此列表里默认展示预先渲染好的 PNG 快照（纯图片，不抢滚动、不重建）。
快照不可用时才回退到直接加载 HTML 文件（`KitHTMLPreview.HTMLPreviewView`）。

快照渲染走 `KitHTMLPreview.HTMLScreenshotter`（`createPDF` + 逐页栅格化），
绕开 `takeSnapshot` 的 tile-based 渲染限制，不会出现黑色未渲染区域。
渲染期间**禁用脚本执行**：LLM 生成的 HTML 可能含脚本，在用户机器上执行它们
没有必要，也避免副作用。

## 时间线消息

工具产出的消息带 `renderKind = "html-canvas"`，并被
`MessageTimelineEvent.isTimelineEvent` 识别，因此**不会回流到 LLM 上下文**——
画布只是给人看的界面产物，不是一次对话轮次。

## 插件策略

`disabledByDefault`。HTML 渲染会启动 WKWebView，开销不小，不该默认对所有用户开启。
启用方式与其它 `disabledByDefault` 插件一致：在设置里显式开启。

## 依赖

- `KernelCore` — `SuperPlugin` / `PluginMetadata` / `KernelCoreContainer`
- `KitAgentTool` — `SuperAgentTool` 工具协议
- `KitHTMLPreview` — `HTMLScreenshotter` / `HTMLPreviewView`
- `ProviderMessage` — 消息模型与时间线事件
- `ProviderMessageRendering` — `MessageRendererItem` 渲染器协议
- `ProviderToolManager` — 工具注册能力
- `ProviderStorage` — 插件数据目录
- `LumiUI` — `AppCard` 等设计系统组件
