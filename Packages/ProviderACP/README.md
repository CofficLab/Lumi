# ProviderACP

ACP（Agent Client Protocol）的契约包：类型定义、传输抽象、会话与权限模型。

## 结构

```
Sources/ProviderACP/
├── ACPTransport.swift      # 传输抽象（本地 stdio；远程 HTTP/WS 预留）
├── ACPMessage.swift
├── ACPTypes.swift
├── ACPSession.swift
├── ACPPermission.swift     # 权限请求模型
├── ACPCapabilities.swift
├── ACPMethods.swift
├── ACPFileSystem.swift
├── ACPError.swift
└── JSONValue.swift         # JSON 值类型
```

## 传输层约定

`ACPTransport` 只搬运字节帧，不做协议语义处理；收到完整帧后回调 `onMessage`。
本地模式通过 stdio，远程模式（三期）计划通过 HTTP / WebSocket。
