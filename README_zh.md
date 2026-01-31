# SwiftUI Template

一个现代化的、基于插件的 macOS SwiftUI 应用程序模板，具有全面的架构和开发工具。

📖 中文版 | [English](README.md)

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🌟 功能特性

### 核心架构
- **插件系统**: 可扩展架构，支持热插拔插件
- **事件驱动**: 完善的组件间通信事件系统
- **MVVM模式**: 清晰的关注点分离，采用现代SwiftUI模式
- **依赖注入**: 集中式服务管理和配置

### 内置插件
- **活动状态** ⌛️: 实时应用程序生命周期状态显示
- **应用信息** ℹ️: 应用程序信息和元数据显示
- **导航** 🧭: 侧边栏导航，可自定义菜单项
- **设置按钮** ⚙️: 状态栏设置访问按钮
- **时间状态** 🕐: 状态栏实时时钟显示
- **版本状态** 🔢: 应用程序版本信息
- **工具栏按钮** 🔘: 可自定义工具栏操作
- **项目信息** 📋: 项目特定信息显示
- **欢迎界面** ⭐️: 引导和欢迎界面

### 开发者体验
- **自动更新**: 集成Sparkle框架的无缝更新
- **全面日志**: 结构化日志，带emoji标识符
- **预览支持**: 广泛的SwiftUI预览支持快速开发
- **代码组织**: Core、Plugins和UI层清晰分离

## 📋 系统要求

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## 🚀 安装

1. **克隆仓库**
   ```bash
   git clone https://github.com/your-username/swiftui-template.git
   cd swiftui-template
   ```

2. **在Xcode中打开**
   ```bash
   open SwiftUI-Template.xcodeproj
   ```

3. **构建和运行**
   - 选择合适的macOS目标
   - 构建 (⌘B) 并运行 (⌘R)

## 🏗️ 项目结构

```
SwiftUI-Template/
├── Core/                          # 核心应用程序框架
│   ├── Bootstrap/                 # 应用程序入口和配置
│   ├── Commands/                  # macOS菜单命令
│   ├── Events/                    # 事件系统定义
│   ├── Providers/                 # 服务提供者和状态管理
│   ├── Repositories/              # 数据访问层
│   └── Views/                     # 核心UI组件
├── Plugins/                       # 插件实现
│   ├── ActivityStatus/            # 活动状态监控
│   ├── AppInfoPlugin/             # 应用程序信息显示
│   ├── NavigationPlugin/          # 导航侧边栏
│   └── ...                        # 其他插件
└── Assets.xcassets/               # 应用程序资源
```

## 🔧 配置

### 插件管理
可以通过设置界面启用/禁用插件：

```swift
// 在PluginSettingsStore中启用/禁用插件
PluginSettingsStore.shared.setPluginEnabled("PluginID", enabled: true)
```

### 日志配置
控制每个组件的日志详细程度：

```swift
// 为特定组件启用详细日志
static let verbose = true  // 在每个符合SuperLog协议的类中
```

## 🛠️ 开发

### 添加新插件

1. **创建插件结构**
   ```swift
   class MyPlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
       static let emoji = "🎯"
       static let verbose = false
       // ... 插件实现
   }
   ```

2. **实现必需方法**
   ```swift
   func addStatusBarLeadingView() -> AnyView? { /* 状态栏内容 */ }
   func addToolBarLeadingView() -> AnyView? { /* 工具栏内容 */ }
   // ... 其他UI贡献方法
   ```

3. **注册插件**
   ```swift
   extension MyPlugin {
       static func register() {
           guard enable else { return }
           Task {
               await PluginRegistry.shared.register(id: id, order: 10) {
                   MyPlugin.shared
               }
           }
       }
   }
   ```

### 事件系统

应用程序使用全面的事件系统进行组件通信：

```swift
// 发送事件
NotificationCenter.postApplicationDidFinishLaunching()

// 监听事件
.onApplicationDidFinishLaunching {
    // 处理应用程序启动
}
```

### 代码风格

- 遵循SwiftUI最佳实践
- 使用`SuperLog`协议保持一致的日志记录
- 为所有UI组件实现全面的预览
- 保持数据、展示和业务逻辑的清晰分离


## 🤝 贡献

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

### 开发指南

- 编写全面的单元测试
- 为新功能更新文档
- 遵循现有的代码风格和模式
- 确保所有预览都能正确编译和显示

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🎯 基于此框架的应用

- **[GitOK](https://github.com/CofficLab/GitOK)** - 综合性项目管理工具，包含自动化脚手架、Git集成和工作流自动化

## 🙏 致谢

- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - 现代UI框架
- [Sparkle](https://sparkle-project.org/) - macOS更新框架
- [MagicKit](https://github.com/magic-kit/magic-kit) - 开发工具包

---

使用 ❤️ 通过 SwiftUI 和现代 macOS 开发实践构建。
