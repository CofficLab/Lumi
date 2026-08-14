# OcrPlugin

使用 macOS Vision 框架对**本地图片文件**做文字识别，并通过 Agent 工具把提取的文本送回对话。

## 特性

- **完全离线**：基于系统自带的 Vision 框架，设备端推理，**不调用任何第三方 API，不产生网络请求**。
- **免费、隐私友好**：图片永不出本机。
- **多语言**：默认简体中文 + 英文，可通过 `language` 参数指定（`en` / `zh` / `zh-TW` / `ja` / `ko` / `fr` / `de` 等）。
- 支持 PNG、JPEG、HEIC、TIFF、GIF 等常见格式。

## Agent 工具

贡献一个工具：

- **`ocr_image`** — 识别本地图片文件中的文字。

参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `path` | string | 是 | 本地图片的绝对路径 |
| `language` | string | 否 | 识别语言提示，默认简体中文 + 英文 |

## 如何启用

本插件策略为 `.optIn`（默认关闭）。在「插件管理」中启用 **OCR 文字识别** 即可。

## 技术实现

- `OcrEngine`：封装 `VNRecognizeTextRequest`，在 `Task.detached` 中执行，避免同步推理阻塞调用线程；无内核依赖，便于单测。
- `OcrImageTool`：实现 `LumiAgentTool`，负责参数解析、路径权限校验（`kernel.isPathAllowed`）、文件类型校验（`UTType`），再委托给 `OcrEngine`。
