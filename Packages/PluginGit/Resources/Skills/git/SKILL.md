# Git 工具使用规范

当任务涉及 Git 版本控制操作时，优先使用内置 Git 工具而非命令行。

## 可用工具

| 工具 | 用途 | 风险等级 |
|------|------|----------|
| `git_status` | 查看仓库状态：当前分支、远程、变更文件分类 | 低 |
| `git_diff` | 查看代码变更：工作区或暂存区的 diff 与统计 | 低 |
| `git_log` | 查看提交历史：支持限制数量、指定分支和文件 | 低 |
| `git_show` | 查看提交详情：作者、日期、变更文件与统计 | 低 |
| `git_branch` | 管理分支：列出、创建、切换 | 创建/切换为中风险 |
| `git_commit` | 提交变更：支持指定文件、amend | 中风险 |
| `git_unpushed` | 检查未推送提交：本地未推送到远程的 commit 数量 | 低 |

## 标准工作流

### 提交前检查
```
1. git_status()      → 了解当前变更概况
2. git_diff()        → 审查具体代码变更
3. git_commit()      → 提交相关变更（提交信息遵循项目既定风格）
4. git_unpushed()    → 确认是否有未推送提交
```

### 代码审查
```
1. git_log()         → 浏览最近提交
2. git_show()        → 查看特定提交的完整变更
3. git_diff()        → 查看当前未提交的变更
```

### 分支操作
```
1. git_branch(action="list")          → 查看本地分支
2. git_branch(action="list", remote=true) → 含远程分支
3. git_branch(action="create", name="feature-xxx") → 创建分支
4. git_branch(action="checkout", name="main")       → 切换分支
```

## 提交规范

- **提交信息**：遵循项目既有的 commit-message 风格（如 Conventional Commits）。
- **粒度**：将相关变更合并提交，避免过大或过碎的提交。
- **amend**：仅在修正最近一次提交时使用 `amend=true`，不要用于修改更早的提交。
- **文件选择**：通过 `files` 参数指定要提交的文件，避免混入无关变更。空列表添加所有变更。

## 注意事项

- 切换分支前若工作区有未提交变更，工具会阻止切换并提示先提交或 stash。
- `git_diff` 默认查看工作区变更，设置 `staged=true` 查看暂存区变更。
- `git_log` 默认返回最近 10 条提交，可通过 `count`（1-50）调整数量。
- `git_show` 需要提供 commit hash（完整或缩写均可）。
- 所有工具支持 `path` 参数指定仓库路径，未提供时默认使用当前项目目录。
