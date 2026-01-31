# SwiftUI Template

A modern, plugin-based SwiftUI application template for macOS with comprehensive architecture and development tools.

📖 [中文版](README_zh.md) | English

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🌟 Features

### Core Architecture
- **Plugin System**: Extensible architecture with hot-swappable plugins
- **Event-Driven**: Comprehensive event system for component communication
- **MVVM Pattern**: Clean separation of concerns with modern SwiftUI patterns
- **Dependency Injection**: Centralized service management and configuration

### Built-in Plugins
- **Activity Status** ⌛️: Real-time application lifecycle status display
- **App Info** ℹ️: Application information and metadata display
- **Navigation** 🧭: Sidebar navigation with customizable menu items
- **Settings Button** ⚙️: Status bar settings access button
- **Time Status** 🕐: Live clock display in status bar
- **Version Status** 🔢: Application version information
- **Toolbar Button** 🔘: Customizable toolbar actions
- **Project Info** 📋: Project-specific information display
- **Welcome Screen** ⭐️: Onboarding and welcome interface

### Developer Experience
- **Auto Updates**: Integrated Sparkle framework for seamless updates
- **Comprehensive Logging**: Structured logging with emoji identifiers
- **Preview Support**: Extensive SwiftUI previews for rapid development
- **Code Organization**: Clear separation between Core, Plugins, and UI layers

## 📋 Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## 🚀 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/swiftui-template.git
   cd swiftui-template
   ```

2. **Open in Xcode**
   ```bash
   open SwiftUI-Template.xcodeproj
   ```

3. **Build and Run**
   - Select appropriate macOS target
   - Build (⌘B) and run (⌘R)

## 🏗️ Project Structure

```
SwiftUI-Template/
├── Core/                          # Core application framework
│   ├── Bootstrap/                 # Application entry and configuration
│   ├── Commands/                  # macOS menu commands
│   ├── Events/                    # Event system definitions
│   ├── Providers/                 # Service providers and state management
│   ├── Repositories/              # Data access layer
│   └── Views/                     # Core UI components
├── Plugins/                       # Plugin implementations
│   ├── ActivityStatus/            # Activity status monitoring
│   ├── AppInfoPlugin/             # Application information display
│   ├── NavigationPlugin/          # Navigation sidebar
│   └── ...                        # Additional plugins
└── Assets.xcassets/               # Application assets
```

## 🔧 Configuration

### Plugin Management
Plugins can be enabled/disabled through the settings interface:

```swift
// Enable/disable plugins in PluginSettingsStore
PluginSettingsStore.shared.setPluginEnabled("PluginID", enabled: true)
```

### Logging Configuration
Control logging verbosity for each component:

```swift
// Enable verbose logging for specific components
static let verbose = true  // in each SuperLog conforming class
```

## 🛠️ Development

### Adding New Plugins

1. **Create Plugin Structure**
   ```swift
   class MyPlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
       static let emoji = "🎯"
       static let verbose = false
       // ... plugin implementation
   }
   ```

2. **Implement Required Methods**
   ```swift
   func addStatusBarLeadingView() -> AnyView? { /* status bar content */ }
   func addToolBarLeadingView() -> AnyView? { /* toolbar content */ }
   // ... other UI contribution methods
   ```

3. **Register Plugin**
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

### Event System

The application uses a comprehensive event system for component communication:

```swift
// Posting events
NotificationCenter.postApplicationDidFinishLaunching()

// Listening to events
.onApplicationDidFinishLaunching {
    // Handle application launch
}
```

### Code Style

- Follow SwiftUI best practices
- Use `SuperLog` protocol for consistent logging
- Implement comprehensive previews for all UI components
- Maintain clear separation between data, presentation, and business logic


## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Write comprehensive unit tests
- Update documentation for new features
- Follow existing code style and patterns
- Ensure all previews compile and display correctly

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Applications Built with This Framework

- **[GitOK](https://github.com/CofficLab/GitOK)** - A comprehensive project management tool with automated scaffolding, Git integration, and workflow automation

## 🙏 Acknowledgments

- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Modern UI framework
- [Sparkle](https://sparkle-project.org/) - macOS update framework
- [MagicKit](https://github.com/magic-kit/magic-kit) - Development utilities

---

Built with ❤️ using SwiftUI and modern macOS development practices.
