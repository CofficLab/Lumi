## 实施计划:让 LLMProviderManager 始终显示设置 tabs,错误展示在详情页

### 问题
`LLMProviderManagerPlugin.swift:70-76` 中,`settingsTabItems` 在依赖缺失(`kernel.lumiCore` / `chatService` / `manager` 任一为 nil)时静默返回空数组,导致 "Local Providers" 和 "Cloud Providers" 两个 tab 从用户侧边栏消失,无任何提示。

### 目标(用户已确认)
1. **始终显示两个 tabs** — 不再静默丢弃
2. **依赖缺失时,详情页顶部显示 `AppErrorBanner` + 详细说明卡片**
3. **子页面运行期错误也通过 banner 兜底**(通过入口 `if let` 避免崩溃)

### 实施步骤

#### 1. 新建 `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Common/SettingsTabDependencyState.swift`

定义依赖解析状态容器 + 错误枚举:

```swift
@MainActor
final class SettingsTabDependencyState: ObservableObject {
    enum Failure: LocalizedError {
        case missingLumiCore
        case missingChatService
        case missingManager

        var errorDescription: String? { ... }
    }

    let chatService: (any LumiChatServicing)?
    let manager: LLMProviderManager?
    let providerSettingsViews: [LumiLLMProviderSettingsViewItem]
    let failure: SettingsTabDependencyState.Failure?

    var isReady: Bool { failure == nil }

    static func resolve(kernel: LumiKernel,
                       managerAccessor: @autoclosure () -> LLMProviderManager?) -> SettingsTabDependencyState
}
```

#### 2. 新建 `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Common/ProviderDependencySettingsView.swift`

通用 wrapper:统一处理 banner + 子视图分发。

```swift
struct ProviderDependencySettingsView<Ready: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ObservedObject var dependencyState: SettingsTabDependencyState
    @ViewBuilder let readyContent: (any LumiChatServicing, LLMProviderManager) -> Ready

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let failure = dependencyState.failure {
                AppErrorBanner(message: failure.errorDescription!)
                DependenciesMissingDetailView(failure: failure)
            } else if let chatService = dependencyState.chatService,
                      let manager = dependencyState.manager {
                readyContent(chatService, manager)
            }
        }
    }
}
```

#### 3. 新建 `DependenciesMissingDetailView.swift`

列出所有依赖的状态(✓/✗),并附上修复建议(在 `AppSettingsSection` 内,使用 `appSurface` 卡片样式,与现有 UI 一致)。

#### 4. 修改 `LLMProviderManagerPlugin.swift`

重写 `settingsTabItems`:

```swift
public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
    // 不再 guard 失败 — 始终注册两个 tab。
    return [
        SettingsTabItem(
            id: "\(id).local",
            title: "Local Providers",
            systemImage: "cpu",
            order: order
        ) {
            let state = SettingsTabDependencyState.resolve(
                kernel: kernel,
                managerAccessor: manager ?? ...
            )
            return AnyView(
                ProviderDependencySettingsView(
                    title: "Local Providers",
                    systemImage: "cpu",
                    dependencyState: state
                ) { chatService, manager in
                    LocalProviderSettingsPage(
                        chatService: chatService,
                        providerSettingsViews: manager.llmProviderSettingsViews(lumiCore: ...),
                        availability: manager.providerAvailabilityState
                    )
                }
            )
        },
        SettingsTabItem(
            id: "\(id).remote",
            title: "Cloud Providers",
            systemImage: "network",
            order: order
        ) {
            // 同样模式
        }
    ]
}
```

**关键点**:`SettingsTabItem.contentBuilder` 本身已经是 `@MainActor @Sendable () -> AnyView`,所以可以在闭包内调用 `SettingsTabDependencyState.resolve(...)`(也是 `@MainActor`)。

#### 5. 可选:`Resources/Localizable.xcstrings`

加几条 `LumiPluginLocalization` 字符串(`provider.*.unavailable` 等)。如果时间紧,先用 `Text(verbatim: ...)` 直接写字符串,之后补本地化。

### 文件清单

| 路径 | 操作 |
|---|---|
| `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/LLMProviderManagerPlugin.swift` | 修改 `settingsTabItems` |
| `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Common/SettingsTabDependencyState.swift` | 新建 |
| `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Common/ProviderDependencySettingsView.swift` | 新建 |
| `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Common/DependenciesMissingDetailView.swift` | 新建 |
| `Plugins/LLMProviderManagerPlugin/Resources/Localizable.xcstrings`(暂未修改) | 已有改动,后期补字符串 |

### 不会修改的部分(已确认)
- `SettingsView.swift` 不需要改(它已经接受 `makeContent()` 的返回并 frame 渲染;wrapper 自己处理 banner + 子视图)
- `SettingsTabItem` 不需要改(type 已稳定,`init` 的 `order` 参数已经存在)
- `BuiltinPluginManager.swift` 不需要改(alwaysOn 插件无条件处理)
- `LocalProviderSettingsPage` / `RemoteProviderSettingsPage` 不需要改(因为 `ProviderDependencySettingsView` 在依赖可用时才调用它们,空指针已被堵死)

### 验证
1. **正常路径**:依赖都可用 → 两个 tab 照常显示,内容跟之前一致
2. **依赖缺失**:重新构建 kernel 但故意不注册 `lumiCore` → 两个 tab 仍在侧边栏,点击进入详情页顶部红色 banner + 卡片提示
3. **编译**:用 `xcodebuild` 或本地 `swift build` 编译 LumiProviderManagerPlugin target 确认无类型错误
4. **没有回归**:插件 `onBoot` 仍照常注册 `LLMProviderManager` 服务,其他插件通过 `kernel.registerLLMProviderService(...)` 注册 provider 不受影响