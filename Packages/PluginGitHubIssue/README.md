# PluginGitHubIssue

让 LLM 在运行过程中把发现的 **Lumi 自身问题**提交到 Lumi 的 GitHub 仓库（`CofficLab/Lumi`）issue 列表。

## 设计

- **目标仓库固定**：`CofficLab/Lumi`。本工具的目的是让 LLM 把 Lumi 的 bug 反馈给维护者，不是给用户项目提 issue。
- 不做 REST API 直连、不存 token：认证由用户已配置的本地 `gh` CLI 管理。
- 工具 `github_create_issue`：先 `which gh` + `gh auth status`，任一失败则返回明确的「gh 不可用 / 未登录」错误文本，LLM 据此放弃提交。
- issue body 自动追加 Lumi 版本、macOS 版本、架构等诊断信息，便于维护者复现。

## 文件

- `GitHubIssuePlugin.swift` — 入口，注册 `github_create_issue` 工具。
- `Tools/CreateGitHubIssueTool.swift` — Agent 工具实现；目标仓库常量 `defaultRepository = "CofficLab/Lumi"`。
- `Services/GitHubCLI.swift` — `gh` 命令的 locate / auth / create 封装。
