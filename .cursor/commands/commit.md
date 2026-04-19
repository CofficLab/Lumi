# Commit Message Rules

按照以下步骤自动创建一个合适的commit：

- 确保构建成功
- 分析最近的commit的风格
- 创建commit

## Steps

- Stage all changes including untracked files: `git add -A`
- Verify staged content: `git status` then `git diff --staged`
- Analyze recent commit style with `git log --oneline -5`
- Create the commit message following Conventional Commits format
- Commit: `git commit -m "<message>"`

## Rules

- Use English for commit messages
- Keep it concise and clear
- Ensure ALL changes are staged before committing — no untracked files left behind
