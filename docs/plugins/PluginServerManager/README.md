# PluginServerManager — 服务器管理

通过 SSH 管理远程服务器的插件（MVP v0.1.0）。默认禁用（`disabledByDefault`），
在「插件管理」中启用后才会出现在 ActivityBar。

## 当前能力

- **连接配置**：添加/移除服务器（名称、主机、端口、用户、分组），持久化在插件数据目录 `servers.json`。
  主机支持 IP、域名或 `~/.ssh/config` 别名；认证复用现有 `~/.ssh` 密钥与 ssh-agent，不保存密码。
  首次连接采用 TOFU 记录主机指纹（`StrictHostKeyChecking=accept-new`），指纹变化拒绝连接。
- **概览**：固定只读脚本采集 OS / 主机名 / 运行时长 / 负载 / 核数 / CPU（/proc/stat 两次采样）/
  内存（free -b）/ 磁盘（df -P），纯函数解析（`ServerMetricsParser`），兼容 Linux 与 macOS 回退。
- **进程管理**：按 CPU 降序的 Top 20 进程；结束进程支持 SIGTERM / SIGKILL，UI 需确认，
  PID 在入口校验范围（1...4_194_304），非法值抛错而非钳制。
- **容器管理**：`docker ps -a` 列表；start / stop / restart 需确认；
  容器名先做字符集校验（`ServerContainer.isValidName`），杜绝命令拼接注入。
- **控制台**：在服务器上执行命令并保留最近 50 条历史。风险分级（`ServerExecRisk`）：
  只读白名单命令 medium；含 shell 元字符（管道/重定向/串联/命令替换）或未知命令一律 high，
  UI 执行前需确认。
- **Agent 工具**：
  - `server_list`（safe）：列出已配置服务器；
  - `server_status`（medium）：返回结构化指标摘要；
  - `server_processes`（low）：Top 进程，`limit` 走 `toolInt` 范围解析（1...20）；
  - `server_container`：list 为 low；start/stop/restart 为 high 且 `requiresExplicitApproval`；
  - `server_exec`：按 `ServerExecRisk` 分级，high 时 `requiresExplicitApproval`（自主模式也不放行）。

## 生命周期

对照 `DiskManagerPlugin`：`onBoot` 注册 Rail / ActivityBar / 主内容 / 工具，
`onDisable` 与 `onShutdown` 对称撤回（含 Agent 工具）。

## 目录结构

```
Sources/PluginServerManager/
├── ServerManagerPlugin.swift      # 插件入口
├── Models/                        # ServerConfig / ServerMetrics / ServerProcess / ServerContainer
├── Services/SSHClient.swift       # 系统 ssh 执行器（参数数组传递，无 shell 拼接）
├── Services/ServerBackend.swift   # actor：配置存储 + 远端操作（runner 可注入测试）
├── Services/RemoteScripts.swift   # 固定远端脚本（===SECTION=== 分段）
├── Services/ServerMetricsParser.swift  # 纯函数解析器
├── Services/ServerExecRisk.swift  # 命令风险分级（纯函数）
├── ViewModels/                    # MainActor ViewModel（异步写回带身份 + 代次校验）
├── Views/                         # 侧栏 / 主视图（概览/进程/容器/控制台）/ 添加表单 / Docs
└── Tools/                         # 5 个 Agent 工具
```

## 测试

`swift test`：32 个测试覆盖持久化、解析器（Linux/macOS/缺省）、风险分级、
工具失败分支、参数校验，以及「旧请求晚到不得覆盖新结果」的门闩回归测试。

## 后续规划

- P1：SFTP 文件浏览与传输、systemd 服务管理、指标历史图表。
- P2：监控历史持久化、告警、ProxyJump 跳板机。
- 发布形态：抽成独立远程仓库 `LumiPluginServerManager`（manifest 包名带 Lumi 前缀，
  product 仍为 `PluginServerManager`），并登记进 `Scripts/check-remote-plugin-package-names.sh`。