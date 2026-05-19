# HttpKit

可复用的 HTTP 传输工具包。提供 JSON 请求编码、响应校验、类型化传输错误、请求元数据与 SSE 事件分帧，供上层领域服务或宿主应用复用。

`HttpKit` 刻意保持在领域层之下，不包含业务请求构建或响应解析逻辑。

## Package

- Product: `HttpKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- JSON request body encoding
- HTTP response validation
- Typed transport errors
- Request metadata with sanitized headers
- SSE event framing over `URLSession.AsyncBytes`
- Default system TLS validation

Domain-specific request building and response parsing belong in callers such as `LLMProviderKit`, `WebFetchKit`, or host app services.

## Testing

From this package directory:

```sh
swift test
```
