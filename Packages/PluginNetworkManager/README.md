# PluginNetworkManager

Network monitoring and HTTP exchange management plugin for Lumi.

Migrated from the legacy `Plugins/NetworkManagerPlugin` (KernelLumi / LumiPlugin architecture) to the new KernelCore / SuperPlugin architecture.

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Features

- **Network Speed Monitoring**: Real-time upload/download speed monitoring via menu bar
- **HTTP Exchange Store**: SwiftData-backed recording of all HTTP requests made by the app
- **7 Agent Tools**: Query HTTP logs, get summaries, check slow/failed requests, domain logs, and download files
- **Process Network Monitor**: Per-process network usage monitoring via `nettop`
- **Network History**: Historical network speed graph with configurable time ranges
- **Settings**: HTTP exchange log viewer and export functionality

## Architecture

- `NetworkManagerPlugin` — Plugin entry point (`SuperPlugin`)
- `NetworkService` — Network speed monitoring singleton
- `NetworkProvider` — `NetworkProviding` implementation with HTTP exchange recording
- `HTTPExchangeStore` — SwiftData-backed HTTP exchange persistence
- 7 Agent tools (HTTP log query, summary, detail, slow requests, failed requests, domain log, file download)

