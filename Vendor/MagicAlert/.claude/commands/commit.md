# 智能生成 Commit Message

自动分析代码更改并生成符合规范的提交信息（Conventional Commits 格式）。

## 工作流程

1. **检查 Git 状态**
   - 运行 `git status` 查看当前仓库状态
   - 识别已暂存和未暂存的更改

2. **分析代码差异并评估版本更新需求**
   - 运行 `git diff --staged` 查看已暂存的更改
   - 如果没有暂存的更改，运行 `git diff` 查看未暂存的更改
   - 分析以下内容：
     - 修改的文件类型（组件、扩展、工具类等）
     - 代码变更的性质（新增、修改、删除、重构等）
     - 影响范围和重要性
   - **根据 commit 类型评估版本更新需求**（仅供参考，版本由 GitHub Actions 自动管理）：
     - **feat** (新功能): → 会自动增加 MINOR 版本 (例如 1.3.4 → 1.4.0)
     - **fix** (bug 修复): → 会自动增加 PATCH 版本 (例如 1.3.4 → 1.3.5)
     - **BREAKING CHANGE** (破坏性变更): → 会自动增加 MAJOR 版本 (例如 1.3.4 → 2.0.0)
     - **docs, chore, style, refactor, test**: → 通常不更新版本
   - 当前版本号通过 `git describe --tags --abbrev=0` 查看最新的 git tag

3. **查看提交历史**
   - 运行 `git log -10 --oneline` 查看最近 10 条提交
   - 了解项目的 commit message 风格和约定

4. **生成 Commit Message**
   - 基于 Conventional Commits 规范：

     ```text
     <type>(<scope>): <subject>

     <body>

     <footer>
     ```

   - **Type（类型）**：
     - `feat`: 新功能
     - `fix`: 修复 bug
     - `docs`: 文档变更
     - `style`: 代码格式（不影响代码运行的变动）
     - `refactor`: 重构（既不是新增功能，也不是修复 bug）
     - `perf`: 性能优化
     - `test`: 增加测试
     - `chore`: 构建过程或辅助工具的变动
     - `revert`: 回滚之前的 commit

   - **Scope（范围）**：
     - `toast`: Toast 相关
     - `manager`: ToastManager 相关
     - `ui`: UI 组件相关
     - `api`: 全局函数 API 相关
     - `docs`: 文档相关
     - 或其他合适的模块名称

   - **Subject（主题）**：
     - 简洁描述（不超过 50 字符）
     - 不以句号结尾
     - 使用祈使句（如 "add" 而非 "added" 或 "adds"）

   - **Body（正文）**：
     - 详细描述更改内容
     - 说明 "为什么" 而非 "是什么"
     - 每行限制在 72 字符以内

   - **Footer（脚注）**：
     - 关联的 Issue
     - Breaking Changes 说明
     - 其他参考信息

5. **显示建议**
   - 展示生成的 commit message
   - 展示更改的文件列表
   - 展示代码差异摘要

6. **版本号检查（仅供参考）**
   - **版本管理说明**：
     - 版本号由 GitHub Actions 自动管理，基于 Conventional Commits 和 git tags
     - 推送到 `main` 分支时，会根据 commit 类型自动计算并创建新版本标签
     - 当前版本号通过 `git describe --tags --abbrev=0` 查看最新的 git tag
   - **版本更新规则**（自动应用）：
     - 如果 commit 类型是 `feat`，会自动增加 MINOR 版本
     - 如果 commit 类型是 `fix`，会自动增加 PATCH 版本
     - 如果有 BREAKING CHANGE，会自动增加 MAJOR 版本
     - 如果是 `docs`, `chore`, `style`, `refactor`, `test`，通常不更新版本
   - **执行 commit**：
     - 直接执行 commit，无需手动管理版本号

7. **执行确认**
   - 询问用户是否使用生成的 commit message
   - 如果确认，执行：
     - `git add` （如果需要）
     - `git commit -m "message"`
   - 如果需要修改，允许用户编辑

## Commit Message 模板

### 简单更改

```text
feat(toast): add loading state indicator
```

### 中等更改

```text
feat(api): add global alert_ functions

Simplify API usage with global functions instead of
MagicMessageProvider.shared.methodName() pattern.

- Add GlobalAlertFunctions.swift
- Implement alert_success(), alert_error(), alert_info() etc.
- Update documentation with new examples
- Add preview examples
```

### 复杂更改

```text
refactor(toast): improve toast container layout

Redesign toast container to support multiple display modes
and better animation transitions.

- Add DisplayMode enum (overlay, banner, bottom, corner)
- Refactor ToastContainer layout logic
- Improve animation curves
- Support multiple toasts on screen
```

### Bug 修复

```text
fix(manager): resolve timer memory leak

Fix timers not being invalidated properly when toast
is dismissed, causing memory leaks.

- Store timer references in dictionary
- Invalidate timers in dismiss method
- Clean up timer dictionary on removal
```

## 示例输出

### 示例 1: 需要版本更新的提交

```text
📝 建议的 Commit Message:

feat(api): add global alert_ functions

Simplify API usage with global functions instead of
MagicMessageProvider.shared.methodName() pattern.

- Add GlobalAlertFunctions.swift
- Implement alert_success(), alert_error(), alert_info() etc.
- Update documentation with new examples
- Add preview examples

Modified files:
  + Sources/MagicAlert/GlobalAlertFunctions.swift (new)
  ~ README.md (modified)
  ~ README_zh.md (modified)
  ~ Sources/MagicAlert/P-ToastPreviews.swift (modified)

ℹ️  版本号信息：
   当前版本: 1.0.0 (最新 git tag)
   Commit 类型: feat (新功能)
   预期版本: 推送到 main 后会自动创建 1.1.0 标签

   注意：版本号由 GitHub Actions 自动管理，无需手动更新。

是否使用此 commit message？(y/n/edit)
```

### 示例 2: 不需要版本更新的提交

```text
📝 建议的 Commit Message:

docs(readme): update installation instructions

Update README with new Swift Package Manager installation
steps and add usage examples.

Changes:
- Update installation section
- Add code examples
- Fix typos

Modified files:
  ~ README.md
  ~ README_zh.md

✅ 版本号检查：
   当前版本: 1.0.0
   Commit 类型: docs (文档更新)
   建议: 不需要更新版本号
   可以直接提交。

是否使用此 commit message？(y/n/edit)
```

## 注意事项

- ✅ 使用中文或英文的 commit message（根据项目约定）
- ✅ 始终分析实际的代码差异
- ✅ 遵循项目的现有 commit 风格
- ✅ 使用清晰、描述性的语言
- ✅ 保持 subject 简洁（< 50 字符）
- ✅ 在 body 中解释 "为什么" 而非 "是什么"
- ✅ **在提交前评估是否需要更新版本号**（见工作流程步骤 6）
- ✅ **版本号更新应单独 commit**，使用格式：`chore: bump version to x.x.x`
- ✅ 使用 Emoji 前缀标识类型（可选）
  - ✨ feat
  - 🐛 fix
  - ♻️ refactor
  - 📝 docs
  - ⚡ perf
  - ✅ test
  - 🎨 chore
- ❌ 不要在没有用户确认的情况下执行 commit
- ❌ 不要忽略 staging area 的状态
- ❌ 不要生成过于通用的 commit message
- ❌ **不要在同一个 commit 中既修改代码又更新版本号**

## MagicAlert 项目约定

### 常用 Scope

- `toast` - Toast 相关
- `manager` - ToastManager 相关
- `ui` - UI 组件相关
- `api` - 全局函数 API 相关
- `docs` - 文档相关

### 版本管理约定

MagicAlert 使用 **Semantic Versioning**（语义化版本）：

- **版本号格式**：`MAJOR.MINOR.PATCH`（例如 1.3.4）
- **版本号存储**：Git tags（例如 `1.3.4`）
- **自动发布**：推送到 `main` 分支时，GitHub Actions 根据 Conventional Commits 自动计算版本并创建标签和 Release

**版本更新规则**：

| Commit 类型 | 版本更新 | 示例 | 说明 |
|------------|---------|------|------|
| `feat` | MINOR +1 | 1.3.4 → 1.4.0 | 新功能（向后兼容） |
| `fix` | PATCH +1 | 1.3.4 → 1.3.5 | Bug 修复 |
| BREAKING CHANGE | MAJOR +1 | 1.3.4 → 2.0.0 | 破坏性变更 |
| `refactor` | 不更新 | - | 代码重构 |
| `docs` | 不更新 | - | 文档更新 |
| `chore` | 不更新 | - | 构建/配置更新 |
| `style` | 不更新 | - | 代码格式 |
| `test` | 不更新 | - | 测试相关 |

**版本更新流程**：

1. 提交代码时使用 Conventional Commits 格式（feat, fix, BREAKING CHANGE 等）
2. 推送到 `main` 分支后，GitHub Actions 会自动：
   - 分析 commit 类型
   - 计算下一个版本号
   - 创建 git tag
   - 创建 GitHub Release
3. 无需手动管理版本号

   ```bash
   git commit -m "feat(api): add new feature"
   ```

**注意事项**：

- ⚠️ **不要**在同一个 commit 中既修改代码又更新版本号
- ⚠️ **不要**在 feature 分支上手动创建 tag
- ⚠️ **不要**手动创建 tag，让 GitHub Actions 自动处理
- ✅ 合并到 `main` 分支后，会自动创建 tag 和 release

## 相关命令

- 使用 `/plan` 在实现复杂功能前进行规划
- 使用 `/code-review` 在 commit 前审查代码
- 使用 `/swift-check` 检查代码规范
