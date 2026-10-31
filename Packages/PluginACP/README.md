# PluginACP

ACP 客户端插件：通过 stdio 驱动外部 ACP Agent，并把会话流式桥接进 Lumi 对话区。

## 结构

```
Sources/PluginACP/
├── PluginACP.swift              # 插件入口（组装层）
├── ACPConfig.swift              # ACP 配置
├── ACPClientCapabilitiesStore.swift
├── ACPClientRequester.swift
├── ACPFileClient.swift
├── ACPFileBridgeTools.swift     # 文件读写桥接为 Agent 工具
├── ACPProtocolHandler.swift
├── ACPSessionManager.swift
├── ACPTurnCoordinator.swift
├── ACPStreamingBridge.swift
├── ACPLocalization.swift
└── Views/
```

协议契约与传输抽象定义在 `ProviderACP`；装配根在 `FactoryLumiACP`。
