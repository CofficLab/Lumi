# Memory Growth Audit - 待办事项

> 上次审计日期：2025-01-20
> 项目路径：`/Users/angel/Code/Coffic/Lumi`

---

## ⚠️ 未完成的修复项

### 1. 插件 disable 时未调用 onDisable/willDisable ✅ 已修复

- **修复位置**：`LumiApp/Services/PluginService.swift:289-295`
- **修复内容**：在 `setPlugin()` 中调用 `await plugin.lifecycle(.willDisable)`
- **注意**：需要各插件实现 `lifecycle(.willDisable)` 来执行清理工作

---

### 2. Terminal 插件未实现清理钩子

- **风险等级**：中
- **当前状态**：`TerminalTabsViewModel.closeAllSessions()` 方法已存在
- **问题**：TerminalPlugin 未实现 lifecycle 来调用清理
- **修复位置**：`Plugins/TerminalPlugin/Sources/TerminalPlugin.swift`

---

### 3. LSPService 单例全局状态问题

- **风险等级**：中
- **当前状态**：`LSPService.shared` 仍为全局单例
- **建议**：评估是否需要按窗口/项目作用域

---

### 4. 窗口关闭时的资源清理

- **风险等级**：高
- **建议**：搜索新架构中是否有 `scenePhase` 或 `terminate` 处理

---

### 5. UI 缓存 AnyView 状态保留

- **风险等级**：中
- **建议**：检查 PluginService 的 UI 聚合逻辑

---

## ✅ 已完成的修复项

| # | 问题 | 状态 | 验证位置 |
|---|------|------|----------|
| 5 | LSP 进度任务 TTL/上限 | ✅ | `LSPProgressProvider.swift` - 10分钟超时 + 32上限 |
| 6 | LSPService stopAll() | ✅ | `LSPService.swift:1107-1132` |
| 7 | RequestLog 统计聚合 | ✅ | 分批聚合 `batchSize=250` |
| 8 | Terminal closeAllSessions | ✅ | 方法已存在 |
| 10 | Database disconnectAll | ✅ | `DatabaseManagerCore.swift:44` |
| 11 | MCPService disconnectAll | ✅ | `MCPService.swift:73` |
| 1 | 插件 willDisable 调用 | ✅ | `PluginService.swift:289-295` |

---

## 优先级排序

1. **P0**：Terminal 插件添加 lifecycle 清理
2. **P1**：窗口关闭资源清理
3. **P2**：LSPService 单例问题
4. **P2**：UI 缓存状态
