# LumiAppKit

Lumi 桌面端的"门面"Swift Package:聚合所有面向 App 层(LumiApp 主入口)的运行时能力,作为 `LumiApp` 与下游子包之间的统一入口。

LumiApp 仅需 `import LumiAppKit` 即可使用本包导出的全部公共符号,无需分别 import LumiCoreKit、LumiUI、SuperLogKit、EditorService 等众多依赖。

## 依赖

| 类别 | 名称 | 说明 |
|------|------|------|
| 本地包 | LumiCoreKit | 核心服务表、插件上下文、状态管理 |
| 本地包 | LumiChatKit | ChatService、ChatSectionCoordinator |
| 本地包 | LumiUI | 主题、表单控件等 UI 组件 |
| 本地包 | SuperLogKit | 统一日志 |
| 本地包 | LumiPluginRegistry | 插件元信息注册表 |
| 本地包 | EditorService | 编辑器命令/状态/会话服务 |
| 本地包 | EditorTextView | 编辑器文本视图组件 |
| 本地包 | EditorPanelPlugin | 编辑器面板相关扩展 |
| 远程包 | [Sparkle](https://github.com/sparkle-project/Sparkle) ≥ 2.5.0 | App 更新 |
| 远程包 | [MagicAlert](https://github.com/nookery/MagicAlert.git) | 通知/告警 UI |

- macOS 部署目标:`14.0`
- Swift tools:`5.9`

## 目录结构

```
Packages/LumiAppKit/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/LumiAppKit/
│   ├── LumiAppKit.swift                 # 包入口文件
│   ├── Bootstrap/                       # 应用启动、容器、窗口
│   ├── Commands/                        # 菜单命令(Settings/Window/Chat/Debug 等)
│   ├── Events/                          # 通知名称定义
│   ├── Services/                        # LumiCoreService、EditorCoreService、MenuBarService 等
│   ├── Storage/                         # 数据目录、版本化目录管理
│   ├── Updates/                         # Sparkle 更新状态机、Feed URL 探测
│   ├── Views/                           # 主窗口布局、面板、设置、菜单栏 UI
│   │   ├── Common/                      # 通用 UI(CrashedView 等)
│   │   ├── Editor/                      # 编辑器作用域视图
│   │   ├── Layout/                      # 主布局:面板、侧栏、聊天、状态栏
│   │   ├── Logo/                        # Logo 资源视图
│   │   ├── MenuBar/                     # 状态栏图标/弹窗
│   │   └── Settings/                    # 设置页与侧栏
│   └── Resources/
│       └── Localizable.xcstrings        # App 层本地化字符串
└── Tests/LumiAppKitTests/               # 单元测试(Updates、Storage、Events)
```

## 子模块职责

| 模块 | 职责 |
|------|------|
| `Bootstrap` | `MacAgent`(NSApplicationDelegate)、`RootContainer`(全局服务容器)、窗口入口 |
| `Commands` | `AppCommands`、`SettingsCommand`、`WindowCommand`、`ChatCommands`、`DebugCommand`、`CheckForUpdatesCommand` |
| `Services` | `LumiCoreService`、`EditorCoreService`、`PluginService`、`MenuBarService`、`LumiUIService`、`UpdateService` |
| `Views` | 主窗口 `WindowMain`、设置窗口 `WindowSettings`、Layout、面板、设置页 |
| `Storage` | `StorageService`:App 数据根目录、版本化目录 |
| `Updates` | `UpdateServiceStateMachine`、`FeedURLDetector`(带 30 分钟缓存) |
| `Events` | App 更新相关 `Notification.Name` 扩展 |

## 使用方式

LumiApp 主入口仅需要:

```swift
import LumiAppKit
import SwiftUI

@main
struct LumiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    var body: some Scene {
        WindowGroup(AppBootstrap.appName, id: AppBootstrap.mainWindowID) {
            WindowMain()
        }
        .commands { AppCommands(); DebugCommand() }
    }
}
```

## 测试

```bash
cd Packages/LumiAppKit
swift test
```

测试覆盖 Updates / Storage / Events 三个领域(共 43 个用例)。

## 构建

```bash
cd Packages/LumiAppKit
swift build
```

> 注意:`swift build` 会解析整个传递依赖图。如遇 `swift-transformers` 上游编译错误(非本包引入),需单独处理其版本问题。