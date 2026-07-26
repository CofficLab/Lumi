## 恢复供应商管理设置页面

### 架构变更

4.19.0 的设置页在 `ModelSelectorPlugin` 中，使用 `ChatService`。新版改为 `LLMProviderManagerPlugin` 负责，通过 `kernel` 获取服务。

### 文件清单

**在 `LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Settings/` 下创建：**

1. **`ProviderSettingsStore.swift`** — 移到 LLMProviderManagerPlugin（当前在 Services 下，无需移动，已在正确位置）

2. **`ProviderSettingsPageBase.swift`** — 抽取两个页面的公共逻辑：
   - 搜索过滤、侧边栏、详情面板布局
   - `selectedProviderID` 状态管理、`ProviderSettingsStore` 持久化
   - 通过 `kernel` 获取 `LLMProviderManaging`、`ConversationManaging`
   - `triggerInitialAvailabilityCheck`、`reloadStats`

3. **`RemoteProviderSettingsPage.swift`** — 远程供应商设置：
   - 筛选 `!isLocal` 的供应商
   - 详情页包含 API Key 管理 + 模型列表
   - 检查 `kernel.settings?.allLLMProviderSettingsItems` 匹配自定义视图
   - 无自定义视图时用默认 UI（API Key 输入框 + ModelCard 列表）

4. **`LocalProviderSettingsPage.swift`** — 本地供应商设置：
   - 筛选 `isLocal` 的供应商
   - 无 API Key 区域
   - 同样支持自定义视图覆盖

### 注册方式

在 `LLMProviderManagerPlugin.swift` 的 `settingsTabItems(kernel:)` 中返回两个 tab：
```swift
SettingsTabItem(id: "...local", title: "Local Providers", systemImage: "cpu", order: 0) { ... }
SettingsTabItem(id: "...remote", title: "Cloud Providers", systemImage: "cloud", order: 1) { ... }
```

### 依赖服务

从 kernel 获取：
- `LLMProviderManaging` — 供应商列表、实例、模型
- `ConversationManaging` — 对话列表、消息（用于统计）
- `SettingsProviding` — 自定义 provider 设置视图 (`allLLMProviderSettingsItems`)
- `LLMProviderManager.providerAvailabilityState` — 可用性检测

### UI 组件复用

- `AppSettingsContentScaffold`, `AppSettingsSection`, `AppSettingsSecureFieldRow`, `AppSettingsDivider` — 已有
- `AppSearchBar`, `AppListRow`, `AppEmptyState` — 已有
- `ModelCard` — 需从 4.19.0 版本带回（上一轮已实现）
- `ModelDailyTokenBarChartMapper`, `ModelUsageStatsService` — 已有

### 注意事项

- `ModelCard` 的 `onSelect` 现在是 `(() -> Void)?` 可选，设置页传 `nil` 即可（不可点击）
- `LLMProviderSettingsItem` 使用 `(Any) -> Content`，需要 cast 为 `LumiLLMProviderInfo` 后传给自定义视图