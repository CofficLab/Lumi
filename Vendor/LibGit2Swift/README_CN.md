# LibGit2Swift

一个基于 [libgit2](https://libgit2.org/) 的类型安全 Swift 封装库，提供原生的 Swift 接口用于 Git 操作。

## 系统要求

- macOS 14.0 或更高版本
- Xcode 15.0 或更高版本
- Swift 5.9 或更高版本

## 安装

### Swift Package Manager

在你的 `Package.swift` 中添加 LibGit2Swift 作为依赖：

```swift
dependencies: [
    .package(url: "https://github.com/nookery/LibGit2Swift.git", from: "1.0.0")
]
```

或者通过 Xcode 添加：

1. File → Add Package Dependencies
2. 输入仓库 URL：`https://github.com/nookery/LibGit2Swift.git`
3. 选择版本规则

## 构建

### 依赖版本

- **libgit2**: v1.9.2
- **OpenSSL**: 3.4.3
- **libssh2**: 1.11.1

### 首次构建步骤

在第一次使用或更新依赖版本后，需要手动构建 `Clibgit2.xcframework`：

```bash
cd Scripts
./build-libgit2-framework.sh
```

#### 构建过程说明

该脚本会自动完成以下操作：

1. 下载依赖源代码：
   - OpenSSL 3.4.3
   - libssh2 1.11.1
   - libgit2 v1.9.2

2. 为以下平台编译静态库：
   - iOS (arm64)
   - iOS Simulator (x86_64)
   - macOS (arm64)
   - macOS (x86_64)
   - Mac Catalyst (arm64 + x86_64)

3. 创建 `Sources/Clibgit2.xcframework` 并复制 module map

#### 构建时的系统要求

- macOS 14.0+
- Xcode 15.0+
- CMake (通常会随 Xcode 安装)
- wget (用于下载源代码)

如果没有安装 wget：

```bash
brew install wget
```

### 构建完成后

构建成功后，会生成 `Sources/Clibgit2.xcframework` 文件。

然后就可以正常使用 Swift Package Manager：

```bash
# 在 LibGit2Swift 目录下
swift build
```

或者在其他项目中：

```bash
cd /path/to/your/project
swift build
```

### 日常开发

一旦 `Clibgit2.xcframework` 构建完成并提交到仓库，后续开发无需再次构建，除非：

1. 需要更新依赖版本（修改 `Scripts/build-libgit2-framework.sh` 中的版本号）
2. 添加新的平台支持
3. 重新生成 xcframework

### 版本更新

如果需要更新依赖版本：

1. 编辑 `Scripts/build-libgit2-framework.sh`
2. 修改以下版本号：
   - `openssl-X.X.X`
   - `libssh2-X.X.X`
   - `vX.X.X` (libgit2)
3. 重新运行构建脚本

## 使用方法

### 初始化仓库

```swift
import LibGit2Swift

// 创建新仓库
let repository = try LibGit2.createRepository(at: "/path/to/project")

// 打开现有仓库
let repository = try LibGit2.Repository(at: "/path/to/existing/repo")
```

### 获取仓库状态

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// 获取 HEAD
let head = try repository.getHead()
print("当前分支: \(head.branchName)")

// 检查是否有未提交的更改
let hasChanges = try repository.hasUncommittedChanges()
```

### 分支操作

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// 列出分支
let branches = try repository.getBranches()

// 创建新分支
try repository.createBranch(name: "feature-branch")

// 删除分支
try repository.deleteBranch(name: "old-branch")

// 重命名分支
try repository.renameBranch(oldName: "old-name", newName: "new-name")
```

### 提交操作

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// 获取提交历史
let commits = try repository.getCommits(maxCount: 10)

// 创建提交
try repository.commit(message: "添加新功能", authorName: "张三", authorEmail: "zhangsan@example.com")

// 添加文件并提交（一步完成）
try repository.addAndCommit(path: "file.swift", message: "添加 file.swift", authorName: "张三", authorEmail: "zhangsan@example.com")
```

### 文件操作

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// 暂存文件
try repository.add(path: "file.swift")

// 暂存所有更改
try repository.addAll()

// 获取文件状态
let status = try repository.getStatus()
```

### 远程仓库操作

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// 列出远程仓库
let remotes = try repository.getRemotes()

// 添加远程仓库
try repository.addRemote(name: "origin", url: "https://github.com/user/repo.git")

// 获取远程 URL
if let url = try repository.getRemoteURL(name: "origin") {
    print("远程 URL: \(url)")
}
```

### 差异操作

```swift
let repository = try LibGit2.Repository(at: "/path/to/repo")

// 获取工作树与索引的差异
let diff = try repository.getDiffWorkingTreeVsIndex()

// 获取索引与 HEAD 的差异
let diff = try repository.getDiffIndexVsHEAD()

// 获取提交之间的差异
let diff = try repository.getDiffCommit(commitOid: "abc123", parentCommitOid: "def456")
```

## 错误处理

LibGit2Swift 提供了全面的错误处理和有意义的错误消息：

```swift
do {
    let repository = try LibGit2.Repository(at: "/path/to/repo")
    // 执行操作...
} catch LibGit2.Error.repositoryNotFound(let path) {
    print("未找到仓库：\(path)")
} catch LibGit2.Error.invalidReference(let message) {
    print("无效引用：\(message)")
} catch {
    print("错误：\(error.localizedDescription)")
}
```

## 许可证

本项目采用 MIT 许可证。更多信息请参见 LICENSE 文件。
