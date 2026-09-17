# Lumi 通过 MCP 操作 Xcode：调研与方案

Status: research, 2026-09-17. 待评审后转 implementation plan。

## 1. 目标

让 Lumi（macOS AI 助手）作为 **MCP 客户端**，连接 Xcode 生态的 MCP 服务器，
把"构建、测试、跑模拟器、编辑工程文件、驱动设备"等 Xcode 能力暴露为 Lumi 的 Agent 工具。

## 2. Lumi 现状盘点（已确认）

- **没有 MCP 客户端支持**：README 明确"当前默认应用尚未提供 MCP 客户端支持，
  仓库中只有少量 MCP 兼容性注释，还没有 MCP 包或 stdio/SSE 传输实现"。
- **已预留接入点**：`KitLLM/Adapters/LLMToolNameSanitizer.swift` 注释明确写了
  "工具 id 来自插件注册（如 `app-store-connect.list-apps`）**或 MCP 服务器**"，
  其按字节转义 + 反向映射的设计天然兼容 MCP 的点号工具名。
- **工具协议**：`KitAgentTool/Sources/SuperAgentTool.swift` 定义 `SuperAgentTool`：
  `name` / `description(for:)` / `inputSchema(for:) -> [String: Any]`（JSON Schema）/
  `permissionRiskLevel(arguments:)` / `execute` / `executeResult` / `displayDescription`。
  插件通过 `ToolManagerProviding.add(_:pluginID:)` 注册工具，宿主负责风险评估与授权。
- **已有互补能力**：
  - `PluginComputerUse`：`accessibility_observe` / `accessibility_act` / `computer_observe` / `computer_act`
    （AX + 原生输入，可操作 Xcode GUI；2026-09-17 已批准"Accessibility-first Computer Use"方案）。
  - `PluginXcodeBuild`：向 `SkillProviding` 贡献 xcodebuild 技能（当前仅示例占位）。
  - `EditorService`：已内嵌 SourceKit-LSP（代码补全/诊断/跳转），构建上下文由 Xcode buildServer 提供。
  - `PluginOpenInXcode` / `PluginTerminal` / `PluginBrewManager`：进程与工具链基础设施。

结论：Lumi 具备完整的"工具注册 → 风险评估 → Agent 循环调度"管道，
MCP 桥接只需新增一个插件包，把 MCP 工具适配成 `SuperAgentTool`。

## 3. 外部生态调研

### 3.1 Apple 官方：Xcode 原生 MCP（推荐主路径）

- Xcode 26.3+ 内置 MCP 服务器：`xcrun mcpbridge`（位于
  `<dev>/usr/bin/mcpbridge`）。无子命令时即 STDIO 桥：从 stdin 读 JSON-RPC 2.0，
  转发到**运行中的 Xcode** 的工具服务。
- 环境变量：`MCP_XCODE_PID`（指定 Xcode 实例，默认跟随 `xcode-select`）、
  `MCP_XCODE_SESSION_ID`（会话 UUID）。
- 使用前提（Apple 文档《Giving external agents access to Xcode》）：
  1. Xcode → Settings → Intelligence → Model Context Protocol →
     **开启 "Allow external agents to use Xcode tools"**；
  2. 外部 Agent 用 `xcrun mcpbridge` 连接；
  3. Xcode 需已打开目标工程；连接与活动时 Xcode 会提示用户。
- 能力（Cursor 集成文档：约 20 个内置工具）：读/编辑工程文件、构建、跑测试、
  SwiftUI 预览渲染、搜索 Apple 文档；Xcode 27 进一步提供
  `device-interaction` 工具（`DeviceInteractionStartSession` /
  `DeviceInteractionInstallAndRun` / `DeviceEventSynthesize` / `DeviceInteractionEndSession`）、
  `lldb-mcp`（调试）、`xcrun agent skills export`（导出 SKILL.md 技能包）、
  "External Agent Access"（应用关闭后仍可访问）。
- 本机现状（已验证）：**Xcode 27.0 (27A266a)**，`/Applications/Xcode.app/Contents/Developer/usr/bin/mcpbridge` 存在，`xcrun mcpbridge --help` 输出与上述一致。

### 3.2 第三方 xcodebuild 封装服务器（无 GUI 依赖）

| 服务器 | 实现 | 说明 |
| --- | --- | --- |
| XcodeBuildMCP | Swift / npm（Cameron Cooke，2026 初被 Sentry 收购） | 包装 xcodebuild + simctl + 模拟器运行时：构建、测试、启动模拟器、安装启动 App、日志、截图、UI 点击。macOS 14.5+ / Xcode 16+，stdio，不需要 Xcode GUI 运行。 |
| xcode-mcp-server | Python / PyPI（r-huijts） | `analyze_file` / `build_project` / `run_tests` 等，基于 xcodebuild，stdio，不需要 Xcode 运行。 |
| xcodebuildmcp | Node / npm（@mseep） | `mcp` 子命令启动服务器，工具清单模式；基于 xcodebuild。 |
| xcode-pilot-mcp 等 | 生态长尾 | 67 工具 / 11 类，覆盖签名、部署等；质量参差。 |

适合"无头构建/测试/模拟器流水线"；不操作 Xcode IDE 本身。

### 3.3 Swift MCP SDK 选型

- **官方 `modelcontextprotocol/swift-sdk`**：唯一实现 MCP 规范客户端的 Swift SDK，
  stdio + SSE（Streamable HTTP 亦在演进），macOS 13+。**注意：MCP 官方分级为 Tier 3
  （实验/部分实现）**——功能可用但需锁版本、补测试、隔离抽象。
- 备选：`Cocoanetics/SwiftMCP`（stdio + HTTP+SSE + 鉴权）、`MCPKit`（客户端配置迁移辅助）。
- 结论：首选官方 swift-sdk，包一层薄协议（`MCPServerServing`），
  便于未来替换或自实现最小 JSON-RPC stdio 客户端。

## 4. 推荐架构

```
Lumi App
├─ Agent 循环 / LLM 工具协议（已有）
├─ ToolManagerProviding（已有）── 风险评估 / 授权 / 任务调度
├─ PluginMCP（新增）
│   ├─ MCPServerRegistry：服务器配置（名称 / 命令 / 参数 / 环境变量 / 传输）
│   ├─ MCPClientCore（KitMCP）：spawn 子进程 → initialize → listTools → callTool
│   ├─ MCPToolBridge：把 MCP 工具适配为 SuperAgentTool（JSON Schema 直通）
│   └─ MCPSettingsView：服务器管理 / 启用开关 / 工具清单 / 连接状态
└─ 内置 Xcode 服务器预设
    ├─ A: xcrun mcpbridge（官方，Xcode 26.3+，需 Xcode 运行 + Intelligence 授权）
    ├─ B: XcodeBuildMCP / xcode-mcp-server（第三方，无 GUI 依赖）
    └─ C:（可选）自研轻量服务器（xcodebuild + simctl + sourcekit-lsp）
```

要点：

1. **工具桥接**：`listTools` 返回的 `inputSchema`（JSON Schema）直接透传给
   `SuperAgentTool.inputSchema(for:)`；`callTool` 结果按 content 类型映射
   （text → 结果文本；image → `ToolCallResult` 图片附件；resource → 文件）。
   工具名经 `LLMToolNameSanitizer` 处理（点号工具名天然兼容）。
2. **权限映射**：MCP 工具默认 `CommandRiskLevel` 中高；
   可按工具前缀归类（读/构建/写工程文件/设备操作），写入现有风险审批流
   （与 `2026-09-17-accessibility-computer-use.md` 的安全边界一致——
   mcpbridge 携 Xcode 的 IDE 权限，属高权限通道，必须显式授权）。
3. **生命周期**：stdio 服务器按需 spawn、空闲回收；崩溃/退出有明确错误回传；
   运行 `run_command` 类工具的沙箱边界同样适用于 MCP 子进程（默认不授予桌面输入/Apple Events）。
4. **内置预设 vs 通用能力**：先做通用 MCP 客户端（用户可添加任意 MCP 服务器），
   再内置 "Xcode (native)" 预设走 Path A。

## 5. 三条 Xcode 接入路径对比

| 维度 | A. 官方 mcpbridge | B. 第三方服务器 | C. 自研轻量服务器 |
| --- | --- | --- | --- |
| 维护方 | Apple | Sentry / 社区 | Lumi 自己 |
| 需 Xcode 运行 | 是（26.3；27 可配置外部代理常驻） | 否 | 否 |
| 覆盖能力 | IDE 级：工程文件、构建、测试、预览、文档、设备（27） | 构建/测试/模拟器 | 可定制，需自建 |
| 用户前置操作 | 开启 Intelligence 授权 + 打开工程 | 安装 npm/pip 包 | 无（内置） |
| 风险 | 权限高（IDE 全权） | 中 | 中 |
| 建议 | **旗舰路径，内置预设** | 作为通用 MCP 能力支持 | 仅在有特殊需求时做 |

推荐落地顺序：**先做 MCP 客户端核心 + 通用服务器管理 → 内置 mcpbridge 预设
→ 验证 Path B 作为可选服务器 → 视需要跟进 Xcode 27 的 skills/lldb-mcp**。

## 6. 风险与权衡

- 官方 swift-sdk 为 Tier 3：锁版本、隔离抽象、补协议级测试；必要时换 `Cocoanetics/SwiftMCP` 或自实现最小客户端。
- mcpbridge 依赖用户开启 Xcode Intelligence 授权 + Xcode 已打开工程：首次引导需在设置页说明步骤。
- 安全：MCP 工具可修改工程文件/触发构建，默认按高风险审批；第三方服务器命令注入面（生态已有历史漏洞，如 ios-simulator-mcp <1.3.3）——只允许用户显式添加的服务器。
- 工具名冲突：多个服务器同名工具需命名空间（`server.tool`）并去重。

## 7. 验证方式

1. KitMCP 单元测试：stdio 进程生命周期、JSON-RPC 消息编解码、listTools→SuperAgentTool 映射。
2. 集成验证：用 `xcrun mcpbridge` 连本机 Xcode 27，实测 listTools 输出工具清单、
   对 Lumi.xcodeproj 执行一次只读查询（如读工程配置）与一次构建。
3. 权限回归：高风险 MCP 调用必须走审批流；拒绝后不得绕过。
4. UI：设置页可增删服务器、启停、查看工具数与连接状态。
