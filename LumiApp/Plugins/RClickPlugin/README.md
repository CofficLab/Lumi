# RClickPlugin (Finder Extension) 实现方案

## 1. 概述
本插件旨在将 RClick 的 Finder 右键菜单功能集成到 Lumi 中。由于 Finder Sync Extension 需要独立的 App Extension Target，无法完全通过 Lumi 的动态插件系统自动生成，因此采用 **“主应用插件 + 手动 Extension Target”** 的混合架构。

## 2. 架构设计

### 2.1 模块划分
*   **Lumi 主应用插件 (`Plugins/RClickPlugin`)**:
    *   负责用户界面（配置菜单项、开关功能）。
    *   负责数据同步（将配置写入 App Group）。
*   **Finder Sync Extension (需手动添加 Target)**:
    *   独立的进程，运行在 Finder 中。
    *   负责读取配置并渲染右键菜单。
    *   执行基础文件操作。

### 2.2 通信机制
使用 **App Groups** (`UserDefaults`) 进行单向通信：
*   **写**: Lumi 主应用将菜单配置（JSON）写入 `UserDefaults(suiteName: "group.com.yourcompany.lumi")`。
*   **读**: Finder Extension 每次显示菜单前读取该配置。

## 3. 详细实现步骤

### Phase 1: 主应用插件开发 (Lumi Side)
1.  **数据模型**: 定义 `RClickMenuItem` (Codable)，包含 `title`, `actionIdentifier`, `isEnabled` 等属性。
2.  **配置界面**: 创建 `RClickSettingsView`，提供开关列表（如 "New File", "Copy Path", "Open in Terminal"）。
3.  **配置管理**: 实现 `RClickConfigManager`，监听设置变化并同步到 App Group。

### Phase 2: Finder Extension 开发 (Xcode Side)
*此步骤需开发者手动操作 Xcode*
1.  **添加 Target**: File -> New -> Target -> macOS -> Finder Sync Extension。
2.  **配置 App Group**: 在主应用和扩展的 Signing & Capabilities 中开启相同的 App Group。
3.  **核心代码 (`FinderSync.swift`)**:
    *   重写 `menu(for:)`: 从 UserDefaults 读取配置，动态构建 `NSMenu`。
    *   实现功能逻辑: 如 `createNewFile()`, `copyPath()` 等。

## 4. 关键代码示例

### 数据同步 (Shared)
```swift
struct RClickAction: Codable {
    let id: String
    let title: String
    let isEnabled: Bool
}

// 保存配置
let actions = [RClickAction(id: "new_file", title: "New File", isEnabled: true)]
if let data = try? JSONEncoder().encode(actions) {
    UserDefaults(suiteName: "group.id")?.set(data, forKey: "RClickActions")
}
```

### 菜单构建 (Extension)
```swift
override func menu(for menuKind: FIMenuKind) -> NSMenu? {
    let menu = NSMenu(title: "")
    let defaults = UserDefaults(suiteName: "group.id")
    
    // 读取配置
    if let data = defaults?.data(forKey: "RClickActions"),
       let actions = try? JSONDecoder().decode([RClickAction].self, from: data) {
        
        for action in actions where action.isEnabled {
            menu.addItem(withTitle: action.title, action: #selector(handleAction(_:)), keyEquivalent: "")
        }
    }
    return menu
}
```

## 5. 待办事项
- [ ] 在 Xcode 中添加 Finder Sync Extension Target。
- [ ] 开启 App Groups 权限。
- [ ] 将生成的 `FinderSync.swift` 代码复制到扩展 Target 中。
