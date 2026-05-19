# HttpKit

Reusable HTTP transport utilities for Lumi packages and app code.

`HttpKit` intentionally stays below domain services. It provides:

- JSON request body encoding
- HTTP response validation
- typed transport errors
- request metadata with sanitized headers
- SSE event framing over `URLSession.AsyncBytes`
- default system TLS validation

Domain-specific request building and response parsing should stay in callers such as `LLMProviderKit`, `WebFetchKit`, or app services.
