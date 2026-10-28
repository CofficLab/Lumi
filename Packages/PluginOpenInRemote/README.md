# PluginOpenInRemote

Lumi 编辑器插件：在默认浏览器中打开当前项目的远程仓库。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginOpenInRemote`
- Platform: macOS 14+, iOS 17+
- Swift tools: 6.0

## 提供什么

- **标题栏按钮**：一键在默认浏览器中打开当前项目 `origin` 远程仓库的网页地址。
- **Agent 工具** `open_in_remote`：在对话中调用可打开当前项目（或指定路径）的远程仓库。
- **地址转换**：把 Git remote 地址转换为浏览器可访问的 HTTPS 链接。

支持的 remote 写法：

| remote 写法 | web 链接 |
|---|---|
| `git@github.com:user/repo.git` | `https://github.com/user/repo` |
| `ssh://git@github.com/user/repo.git` | `https://github.com/user/repo` |
| `https://github.com/user/repo.git` | `https://github.com/user/repo` |
| `git://github.com/user/repo.git` | `https://github.com/user/repo` |

转换规则由 `RemoteWebURLResolver` 实现，是纯函数，便于逐条单元测试。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginOpenInRemote"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginOpenInRemote"]),
]
```

## 能力边界

遵循「插件 Capabilities 能力边界规范」：ViewModel / Tool 只面向本插件声明的窄能力协议，
不直接持有 `any ProjectProviding` / `any GitRepositoryReading` / `any ToastProviding`。

| 能力协议 | Adapter | 收窄自 |
|---|---|---|
| `OpenInRemoteProjectCapability` | `OpenInRemoteProjectCapabilityAdapter` | `ProjectProviding` |
| `OpenInRemoteGitCapability` | `OpenInRemoteGitCapabilityAdapter` | `GitRepositoryReading` |
| `OpenInRemoteToastCapability` | `OpenInRemoteToastCapabilityAdapter` | `ToastProviding` |

内核的 `ProjectProvidingEvent` 与 `ProjectProvidingObserverHandle` 不泄漏给 ViewModel，
Adapter 内部把 `currentProjectChanged(ProjectInfo?, reason:)` 映射为
`OpenInRemoteProjectEvent.currentProjectChanged(String?)`。

Provider 允许为 `nil`（未注册对应能力时）；此时能力退化为「无项目 / 无远程地址」语义，
标题栏按钮保持禁用，Agent 工具返回「未找到远程仓库地址」。

Provider 解析与 Adapter 构造都在插件入口 `onBoot(kernel:)` 完成；**入口强持有 Adapter**，
避免 Adapter 无人持有时静默失效。`onShutdown(kernel:)` 时释放。

## Testing

From this package directory:

```sh
swift test
```
