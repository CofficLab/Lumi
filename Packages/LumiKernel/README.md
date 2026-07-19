# LumiKernel

Lumi 的轻量级核心包，通过依赖反转原则实现解耦。

## 设计理念

LumiKernel 只定义核心协议接口，不包含任何具体实现。所有具体功能通过直接注册方法注入，实现真正的依赖反转。

## 核心协议

- `StorageProviding` - 存储能力
- `ProjectProviding` - 项目管理
- `LayoutProviding` - 布局管理
- `ChatServiceProviding` - 聊天服务
- `EditorServiceProviding` - 编辑器服务
- `AgentToolProviding` - Agent 工具

## 使用方式

```swift
// 1. 创建轻量级核心
let kernel = LumiKernel()

// 2. 直接注册服务（简单明了）
kernel.registerStorage(StorageService())
kernel.registerProject(ProjectService())
kernel.registerLayout(LayoutService())

// 3. 使用服务（通过协议）
if let storage = kernel.storage {
    let pluginDir = storage.pluginDataDirectory(for: "my-plugin")
}
```

## 优势

1. **解耦** - 核心层不依赖具体实现
2. **可测试** - 可以轻松 mock 服务
3. **可扩展** - 新功能通过注册方法添加
4. **轻量** - 真正的核心层，最小依赖
5. **明确** - 直接注册 API，无中间层抽象