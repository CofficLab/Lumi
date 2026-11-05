# PluginGitHubIssue

通过本地 `gh` CLI 把 Agent 遇到的工具故障提交到 GitHub issue。

## 设计

- 不做 REST API 直连、不存 token：认证和仓库都由用户已配置的 `gh` 管理。
- 工具 `github_create_issue`：先 `which gh` + `gh auth status`，任一失败则返回明确的「gh 不可用 / 未登录」错误文本，LLM 据此放弃提交。
- 仓库优先由 `gh` 从 `cwd`（对话绑定的项目路径）的 git remote 推断；LLM 也可通过 `repository` 参数显式指定 `owner/repo`。

## 文件

- `GitHubIssuePlugin.swift` — 插件入口，注册 `github_create_issue` 工具。
- `Tools/CreateGitHubIssueTool.swift` — Agent 工具实现。
- `Services/GitHubCLI.swift` — `gh` 命令的 locate / auth / create 封装。
