# WebFetch Plugin

提供网页抓取和内容提取功能，支持 HTML 转 Markdown。

## 功能

- **WebFetchTool**: 从 URL 抓取内容并自动转换为 Markdown 格式
- **HTMLToMarkdownConverter**: 纯 Swift 实现的 HTML 转 Markdown 转换器

## 工具

### WebFetchTool

从指定 URL 抓取内容，支持多种内容类型：

| 内容类型 | 处理方式 |
|---------|---------|
| HTML | 自动转换为 Markdown |
| JSON | 格式化输出 |
| 纯文本 | 直接返回 |
| 二进制文件 | 保存到临时目录 |
| 图片 | 保存到临时目录 |

**参数**：
- `url` (必须): 要抓取的 URL
- `prompt` (可选): 用于提取关键信息的提示

**特性**：
- 重定向检测（跨域提示）
- LRU 缓存（15 分钟 TTL）
- 内容截断（超过 100KB）
- 60 秒请求超时

## 使用示例

```
// 基本使用
web_fetch url: "https://example.com"

// 提取特定信息
web_fetch url: "https://docs.python.org/library/os" prompt: "file operations"
```

## 目录结构

```
WebFetchPlugin/
├── WebFetchPlugin.swift       # 插件主入口
├── WebFetch.xcstrings         # 本地化字符串
├── WebFetchREADME.md          # 本文档
├── Tools/
│   └── WebFetchTool.swift     # 网页抓取工具
└── Utils/
    └── HTMLToMarkdownConverter.swift  # HTML 转 Markdown
```

## 依赖

- `Foundation`
- `MagicKit`

## 注意事项

- 不支持需要认证的 URL（需要登录、Cookie 等）
- 仅支持 HTTP/HTTPS 协议
- 跨域重定向需要用户确认