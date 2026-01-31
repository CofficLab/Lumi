# 项目结构初始化指令

## 重要规则

请遵循以下代码规范：

- [Swift 代码注释规范](.cursor/rules/swift-comment.mdc)
- [Swift 文件日志记录规范](.cursor/rules/swift-log.mdc)
- [Swift/SwiftUI 视图文件 MARK 分组规范](.cursor/rules/swift-mark.mdc)
- [Swift 文件预览代码规则](.cursor/rules/swift-preview.mdc)
- [Swift 文件事件监听扩展规则](.cursor/rules/swift-event.mdc)

## 准备阶段：项目创建确认

请确保您已通过Xcode创建了一个新的macOS SwiftUI应用项目：

- **平台**: macOS
- **模板**: App (SwiftUI)
- **语言**: Swift

项目应能够正常编译和运行。如果尚未创建，请先完成此步骤。

### 配置项目依赖

在Xcode中添加核心依赖包：

1. 选择菜单 `File` → `Add Packages...`
2. 添加以下包：
   - **MagicKit**: `https://github.com/CofficLab/MagicKit.git` (分支: dev)
   - **Sparkle**: `https://github.com/sparkle-project/Sparkle.git` (版本: 2.0.0+)

**注意**：必须询问用户是否完成，然后才能继续。

## 1. 创建Bootstrap层

**创建Core/Bootstrap/目录结构：**

```text
Core/Bootstrap/
├── YourAppName.swift     # 主入口
├── AppConfig.swift       # 应用配置
├── RootBox.swift         # 服务管理器
├── RootView.swift        # 环境注入
└── MacAgent.swift        # macOS代理（如果需要）
```

**实现核心文件：**

### Core/Bootstrap/YourAppName.swift (主入口)

```swift
import SwiftUI
import Sparkle

@main
struct YourAppName: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent
    private let updaterController: SPUStandardUpdaterController

    init() {
        // 初始化核心库
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentLayout().inRootView()
        }
        .modelContainer(AppConfig.getContainer())
        .commands {
            // 添加您的命令
        }
    }
}
```

#### Core/Bootstrap/AppConfig.swift (应用配置)

```swift
enum AppConfig {
    static func getContainer() -> ModelContainer {
        let schema = Schema([
            // 您的模型类型
        ])
        // 配置SwiftData容器
    }
}
```

#### Core/Bootstrap/RootBox.swift (服务管理器)

```swift
@MainActor
final class RootBox {
    static let shared = RootBox()

    let appProvider: AppProvider
    let dataProvider: DataProvider
    // 其他provider...

    private init() {
        // 初始化所有服务
    }
}
```

#### Core/Bootstrap/RootView.swift (环境注入)

```swift
struct RootView<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(RootBox.shared.appProvider)
            .environmentObject(RootBox.shared.dataProvider)
            // 注入其他环境对象
    }
}

extension View {
    func inRootView() -> some View {
        RootView { self }
    }
}
```

## 3. 创建数据层

**创建目录结构：**

```text
Core/
├── Models/              # 数据模型
├── Repositories/        # 数据访问层
│   ├── BaseRepo.swift
│   └── [ModelName]Repo.swift
└── Providers/           # 服务提供者
    ├── AppProvider.swift
    └── DataProvider.swift
```

**实现Repository模式：**

```swift
protocol BaseRepoProtocol {
    associatedtype Model: PersistentModel
    func findAll(sortedBy: SortDescriptor<Model>) async throws -> [Model]
    func insert(_ model: Model) async throws
    func update(_ model: Model) async throws
    func delete(_ model: Model) async throws
}

class BaseRepo<Model: PersistentModel>: BaseRepoProtocol {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // 实现基础CRUD操作
}
```

## 4. 创建插件架构

**创建目录结构：**

```text
Core/
├── Providers/
│   ├── PluginProvider.swift
│   └── PluginRegistry.swift
└── Contact/
    └── SuperPlugin.swift
Plugins/ 
└── [PluginName]/
    └── [PluginName]Plugin.swift
```

**实现插件系统：**

### Core/Contact/SuperPlugin.swift (插件协议)

```swift
protocol SuperPlugin {
    static var id: String { get }
    static var displayName: String { get }
    static var description: String { get }
    static var iconName: String { get }
    static var isConfigurable: Bool { get }

    // UI贡献方法
    func addToolBarTrailingView() -> AnyView?
    func addStatusBarLeadingView() -> AnyView?
    func addDetailView() -> AnyView?
    func addListView(tab: String, project: Project?) -> AnyView?
}
```

#### Core/Providers/PluginRegistry.swift

```swift
actor PluginRegistry {
    static let shared = PluginRegistry()

    private var factoryItems: [(id: String, order: Int, factory: () -> any SuperPlugin)] = []

    func register(id: String, order: Int = 0, factory: @escaping () -> any SuperPlugin) {
        factoryItems.append((id: id, order: order, factory: factory))
    }

    func buildAll() -> [any SuperPlugin] {
        factoryItems
            .sorted { $0.order < $1.order }
            .map { $0.factory() }
    }
}
```

## 5. 创建基础插件

### Plugins/YourFirstPlugin/YourFirstPlugin.swift

```swift
class YourFirstPlugin: SuperPlugin, PluginRegistrant {
    static var id: String = "YourFirstPlugin"
    static var displayName: String = "您的第一个插件"
    static var description: String = "插件功能描述"
    static var iconName: String = "star"
    static var isConfigurable: Bool = true

    static let shared = YourFirstPlugin()

    private init() {}

    func addToolBarTrailingView() -> AnyView? {
        AnyView(YourPluginView())
    }

    // 实现其他UI贡献方法...
}

// MARK: - PluginRegistrant

extension YourFirstPlugin {
    static func register() {
        guard enable else { return }

        Task {
            await PluginRegistry.shared.register(id: id, order: 1) {
                YourFirstPlugin.shared
            }
        }
    }
}
```

## 6. 创建主布局

**创建目录结构：**

```text
Core/Views/
├── Layout/
│   ├── ContentLayout.swift
│   ├── Sidebar.swift
│   └── ToolbarContent.swift
├── Common/              # 通用组件
├── Settings/            # 设置相关
└── Guide/               # 引导相关
```

**实现主布局：**

### Core/Views/Layout/ContentLayout.swift

```swift
struct ContentLayout: View {
    @EnvironmentObject var pluginProvider: PluginProvider

    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            MainContent()
        }
        .toolbar {
            ToolbarContent()
        }
    }
}
```

## 7. 添加预览支持

为每个主要View添加预览：

```swift
#Preview("Small Screen") {
    ContentLayout()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("Big Screen") {
    ContentLayout()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
```

## 8. 实现设置界面

创建包含侧边栏导航和详情区域的设置界面框架，实现基础的设置管理功能，并实现关于模块显示应用信息。

**创建目录结构：**

```text
Core/Views/Settings/
├── SettingView.swift      # 主设置界面
├── AboutView.swift        # 关于页面
└── [其他设置页面...]
```

**实现SettingView.swift（主设置界面）：**

```swift
import SwiftUI

struct SettingView: View {
    /// 默认显示的 Tab
    var defaultTab: SettingTab = .about

    /// 当前选中的 Tab
    @State private var selectedTab: SettingTab

    /// 设置 Tab 枚举
    enum SettingTab: String, CaseIterable {
        case about = "关于"

        var icon: String {
            switch self {
            case .about: return "info.circle"
            }
        }
    }

    init(defaultTab: SettingTab = .about) {
        self.defaultTab = defaultTab
        self._selectedTab = State(initialValue: defaultTab)
    }

    /// 应用信息
    private var appInfo: AppInfo {
        AppInfo()
    }

    var body: some View {
        NavigationSplitView {
            // 侧边栏
            VStack(spacing: 0) {
                // 应用信息头部
                sidebarHeader

                Divider()

                // 设置列表
                List(SettingTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 200)
        } detail: {
            // 详情区域
            switch selectedTab {
            case .about:
                AboutView()
            }
        }
        .frame(width: 600, height: 500)
    }

    // MARK: - View Components

    /// 侧边栏头部 - 应用信息
    private var sidebarHeader: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: 20)

            // App 图标
            Image(systemName: "app.badge")
                .resizable()
                .frame(width: 64, height: 64)
                .cornerRadius(14)
                .shadow(radius: 3)

            // App 名称
            Text(appInfo.name)
                .font(.headline)
                .fontWeight(.semibold)

            // 版本和 Build 信息
            VStack(alignment: .center, spacing: 2) {
                Text("v\(appInfo.version)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Build \(appInfo.build)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer().frame(height: 16)
        }
        .frame(maxWidth: .infinity)
    }
}
```

**实现AboutView.swift（关于页面）：**

```swift
import SwiftUI

struct AboutView: View {
    /// 应用信息
    private var appInfo: AppInfo {
        AppInfo()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 32) {
                Spacer().frame(height: 40)

                // App 图标和名称
                VStack(spacing: 16) {
                    // App 图标 (暂时用系统图标替代)
                    Image(systemName: "app.badge")
                        .resizable()
                        .frame(width: 128, height: 128)
                        .cornerRadius(20)
                        .shadow(radius: 5)

                    // App 名称
                    Text(appInfo.name)
                        .font(.title)
                        .fontWeight(.bold)

                    // App 版本
                    VStack(spacing: 4) {
                        Text("版本 \(appInfo.version)")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("Build \(appInfo.build)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 信息区域
                VStack(spacing: 24) {
                    // 描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("关于")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(appInfo.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // 基本信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("应用信息")
                            .font(.headline)

                        VStack(spacing: 8) {
                            infoRow(title: "应用名称", value: appInfo.name)
                            infoRow(title: "版本", value: appInfo.version)
                            infoRow(title: "Build", value: appInfo.build)
                            infoRow(title: "Bundle ID", value: appInfo.bundleIdentifier)
                        }
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .navigationTitle("关于")
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

/// 应用信息模型
struct AppInfo {
    let name: String
    let version: String
    let build: String
    let bundleIdentifier: String
    let description: String

    init() {
        let bundle = Bundle.main
        self.name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "YourApp"
        self.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        self.build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        self.bundleIdentifier = bundle.bundleIdentifier ?? "com.yourcompany.YourApp"
        self.description = bundle.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String
            ?? "一个现代化的应用，让您的体验更加简单高效。"
    }
}
```
