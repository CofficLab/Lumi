# PluginGitHubIssue

让 LLM 在运行过程中把发现的 **Lumi 自身问题**提交到 Lumi 的 GitHub 仓库（`CofficLab/Lumi`）issue 列表。

## 设计

- **目标仓库固定**：`CofficLab/Lumi`。本工具的目的是让 Lumi 把 Lumi 的 bug 反馈给维护者，不是给用户项目提 issue。
- **强制英文**：title / body 必须是英文，由工具层强制校验（CJK 字形检测，阈值 3）。非英文内容在调用 `gh` 之前即被拒绝，并返回**英文**提示让 LLM 改写后重试。自动追加的环境诊断表同样全英文。
- 不做 REST API 直连、不存 token：认证由用户已配置的本地 `gh` CLI 管理。
- 工具 `github_create_issue`：先校验英文，再 `which gh` + `gh auth status`，任一失败则返回明确的「gh 不可用 / 未登录」提示，LLM 据此放弃提交。
- issue body 自动追加 Lumi 版本、macOS 版本、架构等诊断信息，便于维护者复现。

## 文件

- `GitHubIssuePlugin.swift` — 入口，注册 `github_create_issue` 工具。
- `Tools/CreateGitHubIssueTool.swift` — Agent 工具实现；目标仓库常量 `defaultRepository = "CofficLab/Lumi"`。
- `Services/GitHubCLI.swift` — `gh` 命令的 locate / auth / create 封装。
- `Support/EnglishLanguageGuard.swift` — 英文校验（按 CJK 字形计数，阈值 3）。
