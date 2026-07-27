## Event Notification 代码迁移计划

### 当前状态分析

**Events 目录已有文件：**
- `Layouts.swift` - View 扩展，监听布局变更通知
- `LumiChatNotifications.swift` - Chat 相关通知
- `MenuBarEvents.swift` - 菜单栏外观变化通知  
- `Notification+Lumi.swift` - 插件启用状态变更通知
- `ProjectEvents.swift` - 项目相关通知

**需要迁移的文件/代码：**

| 文件 | 问题 |
|------|------|
| `Types/LayoutStateTypes.swift` | Notification 相关代码与核心类型混杂 |
| `Services/LumiProviderState.swift` | NotificationCenter 扩展与业务类混杂 |

---

### 迁移方案

#### 1. `Types/LayoutStateTypes.swift` 拆分

**新建 `Events/LayoutEvents.swift`：**
- 所有 `Notification.Name` 扩展（第 10-70 行）
- 所有 `NotificationCenter` 静态方法扩展（第 74-174 行）
- `LayoutEventPayload` 工具类（第 177-184 行）

**保留在 `Types/LayoutStateTypes.swift`：**
- `WorkspaceVisibility` 结构体
- `LayoutStateInfo` 结构体
- `LayoutState` 类

#### 2. `Services/LumiProviderState.swift` 拆分

**新建 `Events/ProviderEvents.swift`：**
- 所有 `NotificationCenter` 扩展（第 89-115 行）

**保留在 `Services/LumiProviderState.swift`：**
- `LumiProviderState` 类本身

---

### 文件结构规划

```
Events/
├── LayoutEvents.swift          # 新建 - 布局事件通知
├── Layouts.swift              # 已存在
├── LumiChatNotifications.swift # 已存在
├── MenuBarEvents.swift         # 已存在
├── Notification+Lumi.swift     # 已存在
├── ProjectEvents.swift         # 已存在
└── ProviderEvents.swift        # 新建 - Provider 状态事件
```

---

### 实施步骤

1. **创建 `Events/LayoutEvents.swift`**
   - 从 `LayoutStateTypes.swift` 迁移 Notification.Name、NotificationCenter 扩展和 LayoutEventPayload

2. **更新 `Types/LayoutStateTypes.swift`**
   - 删除已迁移的内容，保留 WorkspaceVisibility、LayoutStateInfo、LayoutState

3. **创建 `Events/ProviderEvents.swift`**
   - 从 `LumiProviderState.swift` 迁移 NotificationCenter 扩展

4. **更新 `Services/LumiProviderState.swift`**
   - 删除已迁移的 NotificationCenter 扩展

5. **验证编译**
   - 确保所有引用 Notification.Name 和 NotificationCenter 扩展的地方仍然可用

---

### 注意事项

- `LayoutState` 被 `LayoutKernelPlugin`、`LayoutPlugin`、`LumiFactory` 等多处引用，迁移 Notification 相关代码不影响其核心功能
- `LumiProviderState` 本身的 NotificationCenter 扩展是私有的，不影响外部使用