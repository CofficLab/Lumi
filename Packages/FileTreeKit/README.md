# FileTreeKit

文件树核心逻辑包，从 EditorRailFileTreePlugin 提取而来。

## 模块

### FileTreeService

无状态的文件系统工具方法：

- `loadContents(of:)` — 读取目录内容，自动过滤和排序
- `filterAndSortContents(_:)` — 过滤隐藏文件，文件夹优先排序
- `isDirectory(_:)` — 判断 URL 是否为目录
- `iconSFSymbol(forFileExtension:)` — 根据文件扩展名获取 SF Symbol 图标
- `createFile(in:name:)` — 创建新文件
- `createFolder(in:name:)` — 创建新文件夹
- `renameItem(at:newName:)` — 重命名
- `trashItem(at:)` — 移入废纸篓
- `formatDate(_:)` — 格式化日期为相对时间字符串

### FileTreeWatcher

基于 DispatchSource 的目录变化监听器：

- `startWatching(url:)` — 开始监控目录
- `stopWatching(url:)` — 停止监控目录
- `updateWatchedDirectories(_:)` — 批量更新监控列表
- `stopAll()` — 停止所有监控

### FileTreeStore

展开状态和项目路径的持久化存储：

- `expandedPaths(for:)` — 获取展开的目录路径集合
- `setExpandedPaths(_:for:)` — 保存展开路径
- `addExpandedPath(_:for:)` / `removeExpandedPath(_:for:)` — 增删展开路径
- `lastProjectPath()` / `setLastProjectPath(_:)` — 最近项目路径

## 使用

```swift
import FileTreeKit

// 文件操作
let contents = try FileTreeService.loadContents(of: projectURL)

// 目录监听
let watcher = FileTreeWatcher { changedURL in
    print("目录变化: \(changedURL)")
}
watcher.startWatching(url: someDirectory)

// 状态持久化
let store = FileTreeStore(directory: storeDirectory)
store.setExpandedPaths(["/src", "/lib"], for: projectRoot)
```
