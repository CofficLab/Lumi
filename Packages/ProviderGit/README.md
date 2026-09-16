# ProviderGit

Lumi 编辑器 Provider：Git 只读访问契约与数据模型。

> **重要规则：Provider 包描述契约，不包含实现，也不依赖任何插件包。**
>
> 插件需要 Git 数据时依赖本包，而不是反向依赖 `PluginGit`——插件之间不得互相依赖。
> 真实实现由 `PluginGit` 在 `onBoot` 注册。

## 提供什么

### 契约

| 类型 | 说明 |
|------|------|
| `GitRepositoryReading` | 只读访问：`status(atPath:)`、`log(atPath:count:branch:file:)`、`log(atPath:count:skip:)` |
| `InMemoryGitRepositoryReading` | 内存实现，供测试 / 预览 / 无真实 Git 时装配 |

写操作（commit / stage / stash 等）不属于本契约。

### 数据模型

| 类型 | 说明 |
|------|------|
| `GitStatus` | 分支、远程与变更文件分类 |
| `GitCommitLog` | 提交历史中的一条记录 |
| `GitDateFormatting` | 把提交日期字符串解析为 `Date` |
| `GitReadError` | 契约层错误 |

`GitCommitLog.date` 保留 ISO-8601 字符串，避免契约层引入日期解析依赖；
需要 `Date` 的消费者用 `GitDateFormatting.date(from:)`。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../ProviderGit"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["ProviderGit"]),
]
```

消费方在 `onBoot` 解析契约，解析不到时优雅降级：

```swift
guard let git = kernel.resolveProvider((any GitRepositoryReading).self) else { return }
let status = try await git.status(atPath: projectPath)
```

## Testing

From this package directory:

```sh
swift test
```
