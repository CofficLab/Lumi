# PluginGitChatToolbar

Chat Toolbar 上的 Git 只读入口：在聊天输入区工具栏贡献一个胶囊按钮，
点击后弹出面板，分「改动（Changes）」与「提交（Commits）」两段。

参考 GitOK 的 commit 列表与当前工作区变动体验，实现等价的**只读**查看能力。

## 功能

- **Changes 段**：展示当前仓库的工作区变更文件
  - 顶部显示分支徽标与仓库路径
  - 每个文件带变更状态徽标（M / A / D / R / ?）与 staged 标记
  - 点击文件以预览方式切到该文件（`ProjectProviding.previewFile`）
- **Commits 段**：展示最近 50 条提交
  - 每条显示 message、作者、相对时间与短 hash
  - 点击展开该 commit 的变更文件列表，同样可点击定位文件
- **刷新**：面板右上角刷新按钮立即重载；仓库事件触发时自动重载
  （1 秒去抖，合并连续事件）

## 范围

第一版**只读**，不包含 stage / unstage / commit / push、unified diff、
直接打开编辑器或加入对话等写操作。

## 架构

遵循 Lumi 插件规范：

| 层 | 职责 |
|----|------|
| `Capabilities/` | `GitChatCapability`（Git 读取）、`GitChatProjectCapability`（文件预览）窄协议 + Adapter |
| `Observers/` | `GitChatObserver`：把 `ProjectProviding` / `GitRepositoryWatching` 事件翻译成 ViewModel 刷新请求 |
| `ViewModels/` | `GitChatToolbarViewModel`：唯一数据来源，负责去抖与并发丢弃 |
| `Views/` | 胶囊按钮、弹层、列表行等独立视图文件 |

外部事件流：

- 项目切换 → 重载全部
- `indexChanged` / `workingTreeChanged` → 重载 Changes
- `headChanged` / `refsChanged` → 重载 Commits

## 依赖

- `ProviderGit`：Git 仓库只读契约
- `ProviderGitRepositoryWatch`：仓库变更事件
- `ProviderProject`：当前项目与文件预览
- `ProviderChatSection`：Chat Toolbar 贡献点
