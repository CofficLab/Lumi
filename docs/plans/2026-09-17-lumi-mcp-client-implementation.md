# Lumi 通用 MCP 客户端（Cursor 式服务器管理）：实施方案

Status: proposed, 2026-09-17.
前置调研见 `docs/plans/2026-09-17-lumi-mcp-xcode-research.md`（Xcode 生态）；本方案将其升级为
**通用 MCP 客户端能力**：Xcode 是首个内置预设与验证场景，不是唯一目标。

## 1. 产品定位与决策

**产品目标（Cursor 式）**：Lumi 设置中新增"MCP 服务器"入口，用户可自由添加、配置、
启停任意 MCP 服务器（命令/参数/环境变量/传输）。服务器暴露的工具自动进入 Lumi 的
Agent 工具列表，LLM 即可调用——用户因此可以随意扩充 Lumi 的能力生态，
Xcode 控制只是开箱即用的第一个预设。

**决策**：

1. **通用 MCP 客户端为核心能力**：`PluginMCP` 插件 + 设置入口，任何 MCP 服务器
   （stdio / streamable HTTP）都能接入；不做只针对 Xcode 的定制。
2. **内置预设而非唯一实现**：注册表预置 `Xcode (native)`（`xcrun mcpbridge`，
   Xcode 26.3+，本机 27.0 已验证）作为开箱即用入口；另提供常用服务器模板
   （如 XcodeBuildMCP），用户可一键添加后自行修改。
3. **复用现有工具管道**：MCP 工具适配为 `SuperAgentTool` → 注册进
   `ToolManagerProviding` → 复用风险分级、审批流、任务调度、调用记录。
4. **协议层用官方 `modelcontextprotocol/swift-sdk`**（macOS 13+，Tier 3）：
   锁版本并隔离在薄抽象 `MCPServerServing` 之后，必要时可替换
   （`Cocoanetics/SwiftMCP` 或自实现最小 stdio JSON-RPC 客户端）。
5. **风险默认从严**：未知工具按 `high` 处理（需审批）；只读工具按 `safe` 自动执行；
   第三方服务器本质是"本地运行任意程序"，设置页须明示风险并默认关闭"自动信任新服务器工具"。

## 2. 目标与非目标

**目标**：
- 设置页提供 MCP 服务器管理入口：增删改、启停、状态、工具清单、风险展示；
- 用户添加任意 MCP 服务器后，其工具自动出现在 Agent 工具列表并可持续被 LLM 调用；
- 服务器启停、插件卸载时工具随之注册/撤销，不留残留；
- 内置 `Xcode (native)` 预设，开箱即验证"LLM 操作 Xcode"闭环。

**非目标（本阶段）**：
- 不做 MCP 服务器端实现（Lumi 不对外暴露工具为 MCP server）；
- 不做服务器"市场/商店"（仅提供少量内置模板）；
- 不承诺第三方服务器的兼容性——用户自行负责其来源与质量。

## 3. 用户故事（验收标准）

1. **添加**：设置 → MCP 服务器 → "+" → 填名称、`command: xcrun`、`args: ["mcpbridge"]`
   → 保存。服务器状态变为"就绪"，工具列表出现 20 个 Xcode 工具。
2. **使用**：在对话中说"构建一下 Lumi.xcodeproj"，LLM 调用 `BuildProject`，
   经审批后执行，构建日志回传。
3. **扩充**：用户再添加一个 GitHub MCP（`npx -y @modelcontextprotocol/server-github`），
   其工具与 Xcode 工具共存，按服务器分组展示。
4. **启停**：禁用某服务器 → 其工具立即从 Agent 工具列表消失；
   重新启用 → 重新发现并注册。
5. **安全**：新服务器的未知工具默认需审批；用户可在设置中批量调整单工具风险等级。

## 4. 架构与包划分

```
FactoryLumi（宿主装配）
├── KitMCP（新增，纯协议/客户端核心，无 UI 依赖）
│   ├── MCPServerConfig（名称/命令/参数/环境变量/传输/自动启动）
│   ├── MCPServerServing（薄抽象，屏蔽底层 SDK）
│   ├── MCPClientCore（spawn/连接 → initialize → listTools → callTool → 结果解析）
│   └── MCPContentCodec（text/image/resource 结果映射）
├── PluginMCP（新增，插件壳）
│   ├── MCPServerRegistry（内置预设 + 用户服务器，配置持久化）
│   ├── MCPToolAdapter（SuperAgentTool 桥：命名空间、schema 直通、风险分级）
│   ├── MCPPermissionPolicy（默认风险分级 + 未知工具策略 + 单工具覆盖）
│   └── MCPSettingsView（设置入口：服务器管理/添加表单/工具清单/风险/安全提示）
└── 已有：ToolManagerProviding / 风险审批流 / SettingViewProviding / LLMToolNameSanitizer
```

- 插件间不互相依赖；`KitMCP` 是 Kit 包，仅 `PluginMCP` 与宿主依赖。
- 插件元数据：`id = "com.coffic.lumi.plugin.mcp"`，category `.integration`，
  stage `.preview`，policy `.enabledByDefault`；`order` 取 270 附近。

## 5. MCP 服务器模型

```swift
struct MCPServerConfig: Codable, Sendable {
    var id: String            // 全局唯一，作为工具命名空间前缀
    var name: String          // 显示名
    var command: String       // 如 "xcrun" / "npx" / "uvx"
    var arguments: [String]   // 如 ["mcpbridge"] / ["-y", "..."]
    var environment: [String: String]  // 键值对，如 MCP_XCODE_PID；保存时遮蔽显示
    var transport: MCPTransport        // .stdio（默认）/.streamableHTTP
    var url: String?          // streamableHTTP 时的端点
    var autoStart: Bool       // 默认关闭：首次工具调用前按需启动
    var enabled: Bool
}
```

**内置预设（首次写入注册表，用户可改可删）**：

| 预设 | command / args | 说明 |
| --- | --- | --- |
| Xcode (native) | `xcrun mcpbridge` | Apple 官方，Xcode 26.3+；20 个工具；需 Xcode 运行 + Intelligence 授权 |
| Xcode Build (模板) | `npx -y xcodebuildmcp@latest mcp` | 第三方示例模板，无需 Xcode GUI；用户需确认后启用 |

生命周期：按需 spawn（首次工具调用时启动），空闲超时回收，崩溃/退出回传明确错误；
`onShutdown` 停止全部会话并撤销注册的工具。

## 6. 工具桥接细节

- **命名空间**：注册名 `"{serverID}.{toolName}"`（如 `xcode-native.XcodeRead`）；
  跨服务器同名工具天然隔离；单服务器内重名工具去重并告警。
- **名称合规**：注册前经 `LLMToolNameSanitizer` 转义，流式解析时反向还原原始注册名。
- **Schema 直通**：`listTools` 的 `inputSchema` 直接作为 `SuperAgentTool.inputSchema(for:)`；
  参数解码复用 `ToolArgumentCoding`。
- **结果映射**：`text` → 结果文本；`image` → `ToolCallResult.images`；
  `resource` → 文件/文本内容；错误 → `isError: true` 保留 MCP 错误码与消息。
- **展示**：`displayDescription` 用 "动词 + 关键参数"；`description(for:)` 中英双语。
- **执行能力**：工具可通过策略声明并行只读（如 Read/List/Get 类）；其余默认 `.serialSideEffect`。

## 7. 风险分级与审批

| 等级 | 策略 | 覆盖范围 |
| --- | --- | --- |
| safe | 自动执行，可并行 | 明确的只读类工具（读文件/搜索/列表/查询） |
| medium | 自动执行，串行 | 耗时/轻度副作用（跑测试、渲染预览） |
| high | 走审批流 | 写文件、删除、构建、执行代码、未知工具 |

- **未知工具默认 `high`**：防止新服务器/新版本悄悄获得权限。
- **默认风险表按工具名匹配**（Xcode 预设逐项列出，见调研文档第 5 节）；
  用户可在设置页覆盖单个工具的风险等级。
- **审批交互**：复用 `ToolManagerProviding.executeBatch(.requireApprovalForHighRisk)`
  与现有 `ToolApprovalPendingView`（V1/V2/V3 已有路径），MCP 工具零额外 UI。
- **安全提示**：添加服务器时明示"该服务器将在本机以 Lumi 权限运行程序，
  相当于本地执行任意命令；请仅添加可信来源"。环境变量显示时遮蔽值，支持单独编辑。

## 8. 设置页设计（Cursor 式）

入口：Lumi 设置侧边栏新增 **"MCP 服务器"** 条目（`SettingViewProviding.addEntries`，
图标 `link` / `plugs`，靠近"工具/集成"类条目）。

页面结构：

1. **服务器列表**：卡片式；每项显示名称、状态（运行中/就绪/错误/已禁用）、
   工具数、启停开关、编辑/删除。
2. **添加/编辑表单**：
   - 名称、传输（stdio / Streamable HTTP）、命令、参数（每行一个）、
     环境变量（键值对列表，值默认遮蔽）、自动启动开关；
   - "保存并连接"按钮：保存后立即尝试发现工具，成功显示工具清单，失败显示错误文案。
3. **内置模板区**：`Xcode (native)`、`Xcode Build` 等一键添加；含使用前置条件说明
   （如 Xcode 需运行 + Intelligence 授权，附操作路径）。
4. **工具清单**：按服务器分组；每工具显示名称、描述、风险等级徽标、启用开关；
   支持按风险等级筛选、批量禁用高风险。
5. **全局设置**：MCP 总开关；未知工具默认风险等级；是否自动连接 autoStart 服务器。

## 9. 分阶段任务

### Phase 1：KitMCP 客户端核心

**Task 1.1 — KitMCP 包骨架与传输层**
- 新建 `Packages/KitMCP`（macOS 14+，Swift 6）；依赖官方 `modelcontextprotocol/swift-sdk`（锁版本）。
- `MCPTransport`：stdio（spawn `Process`，newline-delimited JSON-RPC）；
  streamable HTTP 仅留接口与基础实现。
- 验证：`swift test` 空包；`Process` 生命周期单测（启动/退出/超时）。

**Task 1.2 — MCPClientCore 会话**
- `MCPServerServing` 协议：`connect() / listTools() / callTool(name:arguments:) / disconnect()`。
- 实现：`initialize` 握手、工具发现、调用分发、错误码映射。
- 验证：mock 服务器进程回放 JSON-RPC（含错误路径）。

**Task 1.3 — 内容编码与结果模型**
- `MCPContentCodec`：text/image/resource → `ToolCallResult`。
- 验证：编解码往返测试。

### Phase 2：PluginMCP 通用桥接 + 设置入口（核心交付）

**Task 2.1 — 服务器注册表**
- `MCPServerRegistry`：配置模型 + 持久化（JSON，复用现有存储约定）；
  内置预设首次写入；增删改查、启停状态机。
- 验证：注册表 CRUD、持久化往返测试。

**Task 2.2 — MCPToolAdapter 桥**
- 实现 `SuperAgentTool`；工具发现后批量注册（pluginID 归属本插件），
  服务器停止/插件卸载按名移除。
- 命名空间、`LLMToolNameSanitizer`、schema 直通、结果映射。
- 验证：mock 服务器（read-only + write + image 各一）全链路注册/调用/移除。

**Task 2.3 — 风险分级策略**
- `MCPPermissionPolicy`：默认分级表、未知工具策略、单工具覆盖、参数启发
  （如删除/写入目标路径在工程外 → 强制 high）。
- 验证：分级表单测；高危必审批、拒绝后不执行。

**Task 2.4 — 设置页（Cursor 式）**
- `MCPSettingsView`：第 8 节全部交互；含添加表单校验（command 非空、
  HTTP 传输需 URL）、保存并连接、模板区、工具清单、安全提示。
- 验证：无服务器/多服务器/连接失败三种状态 UI 可运行（集成构建）。

**Task 2.5 — 宿主装配**
- `FactoryLumi`：添加 `PluginMCP` 依赖与实例；onBoot 注册设置条目与空注册表，
  onShutdown 全部清理。
- 验证：`swift test` 全量 + App 集成构建。

### Phase 3：Xcode 预设 + 真实集成验证（首个用例闭环）✅ 已完成

**Task 3.1 — 内置预设落库** ✅：注册表首次初始化预置 `Xcode (native)`（`xcrun mcpbridge`，禁用态）+ 模板一键添加。

**Task 3.2 — 真实链路验证（本机 Xcode 27.0 (27A266a) 实测完成）** ✅
- 前置：Xcode 打开 Lumi.xcodeproj，Intelligence → Model Context Protocol 开启。
- 实测（`/tmp/mcp-probe`，KitMCP stdio 直连）：
  - `connect`（initialize 握手）→ `listTools`：**54 个工具**（调研预期 20 个，Xcode 27 新增 DeviceInteraction*、StringCatalog*、XcodeNewProject/NewTarget、RunProject/StopProject、RunCodeSnippet、AddEntitlement/AddInfoPlist、GetConsoleOutput、GetCrashIssueLogs 等）；
  - `XcodeOpenWorkspace` → 打开 Lumi.xcodeproj，返回 `workspaceIdentifier`；
  - `XcodeListWorkspaces` / `XcodeGlob` / `XcodeGrep` / `XcodeRead` 全部成功（XcodeRead 读 LumiApp.swift 167 行，cat -n + JSON 编码，与 LLM 视角一致）。
- **关键实测发现（写回实现）**：
  1. **Xcode 27 授权是逐 agent + 逐工程文件夹**：首次调用须先 `XcodeOpenWorkspace`/`XcodeNewProject` 触发 Xcode UI 授权（MCP 菜单栏图标），或 `sudo xcrun mcp-server approve <id>`；未授权调用返回 "This agent isn't approved…" 错误。
  2. 多数工具（XcodeRead/Grep/Glob 等）要求 `workspaceIdentifier` 参数（来自 XcodeOpenWorkspace/ListWorkspaces）。
  3. `xcode-select` 指向 Xcode 时 `xcrun mcpbridge` 可用；`process.executableURL = fileURLWithPath(command)` 不解析 PATH → KitMCP 改用 `/usr/bin/env` 启动（兼容 xcrun/npx/uvx）。
- 54 个真实工具全量回写 `MCPPermissionPolicy.exactRuleTable`（safe 23 / low 1 / medium 6 / high 24）。

**Task 3.3 — 故障与降级** ✅
- 覆盖：未授权（agent/folder）、等待批准、无打开工作区，`MCPToolAdapter.friendlyHint` 识别 mcpbridge 已知错误并追加中文可操作提示（透传原文）；未连接/进程退出/传输错误已有中文包装。
- 测试：18+3 本地化测试全绿。

### Phase 4：可选增强（不阻塞主线）

- 更多内置模板（GitHub、Filesystem、Playwright 等常用服务器）；
- Xcode 27 `xcrun agent skills export` 技能包导入（SKILL.md → `SkillProviding`）；
- `lldb-mcp` 调试工具接入（Xcode 27）；
- streamable HTTP 认证（Authorization header）与重连策略。

## 10. 验证方式汇总

| 层 | 验证 |
| --- | --- |
| 单元 | KitMCP JSON-RPC/编解码、桥接映射、风险分级表、注册表持久化 |
| 集成 | 真实 mcpbridge：listTools 20 工具、safe 直执行、high 审批、结果回传 |
| 多服务器 | 同时启用 Xcode 与第二个 mock 服务器，工具共存、命名隔离、分别启停 |
| 权限 | 高危必审批；拒绝后不执行；未知工具默认 high；单工具风险可覆盖 |
| 构建 | 各包 `swift test` + App `xcodebuild` 集成构建 |
| UI | 设置入口、添加表单、启停、工具清单、安全提示真机运行 |

## 11. 风险与回退

- **swift-sdk Tier 3**：锁版本 + `MCPServerServing` 隔离；阻塞时回退
  `Cocoanetics/SwiftMCP` 或自实现最小 stdio JSON-RPC 客户端。
- **第三方服务器 = 任意代码执行面**：设置页强提示；未知工具默认 high；
  默认不自动连接；环境变量值遮蔽显示。
- **进程管理**：服务器子进程需超时、回收、崩溃上报；长时间构建类调用不阻塞 Agent 循环
  （复用 ToolJob 后台执行模型）。
- **工具名冲突**：命名空间前缀 + 去重；冲突工具不注册并告警。
