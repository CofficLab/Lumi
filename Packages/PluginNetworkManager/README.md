# PluginNetworkManager

Network monitoring and HTTP exchange management plugin for Lumi.

Migrated from the legacy `Plugins/NetworkManagerPlugin` (KernelLumi / LumiPlugin architecture) to the new KernelCore / SuperPlugin architecture.

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
