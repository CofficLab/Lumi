# MagicAlert Git 工作流程指南

本文档定义了 MagicAlert Swift Package 的 Git 分支管理和版本发布策略。

## 📋 目录

- [分支策略](#分支策略)
- [日常开发流程](#日常开发流程)
- [提交规范](#提交规范)
- [版本发布流程](#版本发布流程)
- [常见场景](#常见场景)
- [故障排查](#故障排查)

---

## 分支策略

### GitHub Flow

MagicAlert 使用 **GitHub Flow** 工作流：

```
main (始终可部署)
  ↑
  │ Pull Request
  │
feature/new-feature (开发)
```

### 分支说明

| 分支 | 用途 | 稳定性 | 标签 | 保护规则 |
|------|------|--------|------|----------|
| **main** | 生产就绪，始终可部署 | ⭐⭐⭐ 生产级 | ✅ 自动打标签 | 🔒 推送保护 |
| **feature/*** | 功能开发 | ⭐ 开发中 | ❌ 不打标签 | ❌ 无限制 |

### 分支命名规范

```
feature/功能描述        # 新功能开发
fix/问题描述           # Bug 修复
refactor/模块名称      # 重构
docs/文档内容          # 文档更新
hotfix/问题描述        # 紧急修复（从 main 创建）
```

示例：
- `feature/error-handling`
- `fix/loading-toast-memory`
- `refactor/global-functions`
- `docs/readme-update`

### 核心原则

1. **main 分支始终可部署**：任何时间点，main 分支的代码都应该是可以发布的状态
2. **功能分支短期存在**：feature 分支在完成功能后立即删除
3. **通过 PR 合并**：所有代码变更通过 Pull Request 合并到 main
4. **自动发布**：合并到 main 后自动触发版本发布流程

---

## 日常开发流程

### 场景 1：开发新功能 ✨

```bash
# 1. 确保本地 main 是最新的
git checkout main
git pull origin main

# 2. 创建功能分支
git checkout -b feature/your-feature-name

# 3. 开发和提交（使用 /commit 命令生成规范的提交消息）
git add .
git commit -m "feat: add custom toast duration"

# 4. 推送到远程
git push -u origin feature/your-feature-name

# 5. 在 GitHub 上创建 Pull Request
# - 访问 https://github.com/nookery/MagicAlert/pull/new/feature/your-feature-name
# - 填写 PR 描述
# - 等待 CI 检查通过

# 6. 合并 PR 到 main
# - 在 GitHub 上点击 "Merge pull request"
# - 合并后自动触发发布流程

# 7. 删除本地功能分支
git checkout main
git pull origin main
git branch -d feature/your-feature-name
```

### 场景 2：修复 Bug 🐛

```bash
# 1. 从 main 创建修复分支
git checkout main
git pull origin main
git checkout -b fix/bug-description

# 2. 修复并提交
git add .
git commit -m "fix: resolve toast dismiss timer leak"

# 3. 推送并创建 PR
git push -u origin fix/bug-description
# 在 GitHub 上创建 PR 并合并
```

**重要**：如果是影响生产环境的紧急 Bug，需要：
1. 从 main 创建 `hotfix/bug-description` 分支
2. 快速修复并合并到 main
3. 自动触发紧急发布

### 场景 3：代码重构 🔧

```bash
# 1. 创建重构分支
git checkout main
git pull origin main
git checkout -b refactor/module-name

# 2. 进行重构
# ...

# 3. 确保测试通过
swift test

# 4. 推送并创建 PR
git push -u origin refactor/module-name
# 在 GitHub 上审查并合并
```

---

## 提交规范

### Conventional Commits 格式

MagicAlert 使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### 类型（Type）

| 类型 | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat: add custom toast duration` |
| `fix` | Bug 修复 | `fix: resolve toast dismiss timer leak` |
| `refactor` | 重构 | `refactor: simplify toast container logic` |
| `docs` | 文档更新 | `docs: update README with new API` |
| `test` | 测试相关 | `test: add unit tests for global functions` |
| `chore` | 构建/工具/依赖更新 | `chore: upgrade Swift version` |
| `perf` | 性能优化 | `perf: optimize toast animation` |
| `ci` | CI 配置 | `ci: add GitHub Actions workflow` |
| `style` | 代码格式 | `style: fix indentation in ToastView` |

### 作用域（Scope）

可选，用于指明提交影响的模块：

- `toast` - Toast 相关
- `manager` - ToastManager
- `ui` - UI 组件
- `api` - 全局函数 API
- `docs` - 文档

### 示例

```bash
feat(api): add global alert functions
fix(manager): resolve timer memory leak
refactor(ui): simplify toast container layout
docs(readme): update usage examples
chore(deps): bump deployment target
```

### 多行提交

```bash
git commit -m "feat: add global alert functions

- Add alert_success(), alert_error(), alert_info() etc.
- Simplify API usage for developers
- Update documentation with new examples
- Add preview examples

Closes #42"
```

---

## 版本发布流程

### 语义化版本（Semver）

MagicAlert 遵循 [Semantic Versioning 2.0.0](https://semver.org/)：

```
MAJOR.MINOR.PATCH

例：1.4.0
  │  │  └─ PATCH：Bug 修复（向后兼容）
  │  └──── MINOR：新功能（向后兼容）
  └─────── MAJOR：破坏性变更
```

### 自动发布流程

MagicAlert 使用 GitHub Actions 自动化发布流程：

1. **触发条件**：代码合并到 `main` 分支
2. **自动执行**：
   - 计算下一个版本号
   - 生成变更日志
   - 创建 Git 标签
   - 创建 GitHub Release

### 手动发布（如需）

```bash
# 1. 确保 main 是最新的
git checkout main
git pull origin main
swift test

# 2. 创建标签（如需手动控制版本）
git tag -a v1.4.0 -m "Release v1.4.0: Add global alert functions

Features:
- Global alert_ API functions
- Improved toast animation
- Bug fixes for timer management"

# 3. 推送标签
git push origin v1.4.0
```

### 版本号决策树

```
是否包含破坏性变更？
├─ 是 → MAJOR +1 (1.3.7 → 2.0.0)
└─ 否 → 是否有新功能？
         ├─ 是 → MINOR +1 (1.3.7 → 1.4.0)
         └─ 否 → PATCH +1 (1.3.7 → 1.3.8)
```

### CHANGELOG 维护

变更日志由 GitHub Actions 自动生成，发布新版本时自动更新。

```markdown
## [1.4.0] - 2026-01-31

### Added
- Global alert_ function API
- Custom toast duration support
- Improved animation curves

### Fixed
- Memory leak in timer management
- Toast display overlap issue
- Loading toast not dismissing properly

### Changed
- Simplified API usage
- Updated documentation
```

---

## 常见场景

### 场景 1：发现提交写错了

```bash
# 如果还没有推送到远程
git commit --amend -m "fix: correct typo in function name"

# 如果已经推送，创建新的提交
git commit -m "fix: correct function name typo"
```

### 场景 2：需要撤销最近的提交

```bash
# 保留更改，撤销提交（功能分支上）
git reset HEAD~1

# 完全撤销提交和更改（功能分支上）
git reset --hard HEAD~1
```

⚠️ **永远不要 force push main 分支**

### 场景 3：功能分支落后于 main

```bash
git checkout feature/your-feature
git fetch origin main
git rebase origin/main
```

### 场景 4：在功能分支上同步 main 的最新更改

```bash
git checkout feature/your-feature
git fetch origin main
git rebase origin/main
git push origin feature/your-feature --force
```

---

## 故障排查

### 问题 1：标签推送失败

**症状**：`git push` 没有包含新标签

**解决方案**：
```bash
# 推送所有标签
git push origin --tags

# 推送特定标签
git push origin v1.4.0
```

### 问题 2：自动发布失败

**症状**：合并到 main 后没有触发 release workflow

**检查清单**：
1. 确认 `.github/workflows/` 目录存在工作流文件
2. 确认 GitHub Actions 已启用
3. 检查 Actions 标签页查看错误信息
4. 确认版本计算脚本存在且有执行权限

### 问题 3：不小心在 main 上直接提交

**解决方案**：
```bash
# 1. 创建功能分支并保留提交
git checkout -b feature/retrospective

# 2. 推送并创建 PR
git push -u origin feature/retrospective

# 3. 重置 main 到远程状态
git checkout main
git reset --hard origin/main
```

---

## 最佳实践

### ✅ 推荐做法

1. **小步提交**：频繁提交，每次提交一个完整的逻辑单元
2. **清晰的提交消息**：让未来的自己理解为什么要做这个更改
3. **保持 main 稳定**：所有变更通过 PR 审查后再合并
4. **功能分支短期存在**：完成后立即删除，不要长期保留
5. **写好 PR 描述**：说明为什么要做这个更改，做了什么
6. **等待 CI 通过**：确保测试通过后再合并 PR

### ❌ 避免做法

1. **不要直接在 main 上开发**（除了紧急 hotfix）
2. **不要推送未测试的代码**
3. **不要使用 `git push --force` 到 main**
4. **不要让功能分支长期存在**：及时合并或关闭
5. **不要忽略合并冲突**：及时解决，不要堆积
6. **不要合并后立即删除分支**：等确认无误后再删除

---

## 工具和命令速查

### 常用命令

```bash
# 查看状态
git status
git log --oneline --graph --all --decorate

# 分支操作
git branch -a                          # 查看所有分支
git checkout -b new-branch             # 创建并切换分支
git branch -d old-branch               # 删除本地分支

# PR 相关
git checkout main && git pull          # 确保 main 最新
git checkout -b feature/name           # 创建功能分支
git push -u origin feature/name        # 推送并跟踪

# 合并操作（功能分支上）
git rebase origin/main                 # 同步 main 的最新更改
git rebase --continue                  # 解决冲突后继续

# 标签操作
git tag                                # 查看所有标签
git tag -a v1.0.0 -m "message"        # 创建标签
git push origin --tags                # 推送所有标签

# 远程操作
git remote -v                          # 查看远程仓库
git fetch --all                        # 获取所有远程更新
```

---

## 附加资源

- [Git 官方文档](https://git-scm.com/doc)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)

---

**最后更新**：2026-01-31
**维护者**：nookery
**工作流**：GitHub Flow
