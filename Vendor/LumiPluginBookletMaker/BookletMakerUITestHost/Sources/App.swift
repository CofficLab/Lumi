import SwiftUI
import KernelCore
import LumiLocalizationKit
import LumiUI
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderTheme
import ProviderToolbar
import PluginBookletMaker

/// 最小宿主 App，仅用于 UI 测试。
///
/// 装配顺序与真实宿主（GameFactory 的 `BookletMakerApp`）一致：
/// **注册 Provider → 启动插件 → 组装视图**。插件 `onBoot` 会向 Rail 注册
/// tab、向 ContentView 注入内容区，任何一步提前都会导致界面缺少对应区域。
@main
struct BookletMakerTestHostApp: App {
    @StateObject private var container = TestHostContainer()

    var body: some Scene {
        WindowGroup {
            Group {
                if let layout = container.layout {
                    layout
                        .onAppear {
                            // 激活放在 onAppear：此时布局已挂载，
                            // ActivityBar 的激活闭包能正确设置 Rail 可见性。
                            
                            container.activatePlugin()
                            container.seedMergeQueueIfRequested()
                        }
                } else {
                    ProgressView()
                        .accessibilityIdentifier("host.loading")
                }
            }
            .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
    }
}

/// 测试宿主容器：装配 Provider、启动插件、产出根布局。
@MainActor
final class TestHostContainer: ObservableObject {
    @Published var layout: TestHostRootLayout?

    private let kernel = KernelCoreContainer()
    private let plugin = BookletMakerPlugin(
        // 宿主专属命名空间，与 GameFactory / Lumi 一致，
        // 保证插件数据目录独立于共享包的默认值。
        id: "com.coffic.bookletmaker.plugin.booklet-maker",
        policy: .required
    )

    private var toolbar: (any ToolbarProviding)?
    private var activityBar: (any ActivityBarProviding)?
    private var rail: (any RailViewProviding)?
    private var contentView: (any ContentViewProviding)?
    private var hasSeededMergeQueue = false

    init() {
        Task { @MainActor in
            setupProviders()
            bootPlugin()
            buildLayout()
        }
    }

    // MARK: - Assembly

    /// 注册 UI 测试所需的 Provider。
    ///
    /// 与真实宿主的差异：真实宿主还会装配 CommandProviding（系统菜单）与
    /// 设置侧栏插件。UI 测试不覆盖菜单路径，省略以避免依赖宿主专属包。
    private func setupProviders() {
        do {
            try kernel.registerProvider((any ActivityBarProviding).self, DefaultActivityBarProviding())
            try kernel.registerProvider((any RailViewProviding).self, DefaultRailViewProviding(visibleCategories: [.design]))
            try kernel.registerProvider((any RootViewProviding).self, DefaultRootViewProviding())
            try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
            try kernel.registerProvider((any ToolbarProviding).self, DefaultToolbarProviding())
            try kernel.registerProvider((any DocsViewProviding).self, DefaultDocsViewProviding())
            try kernel.registerProvider((any ThemeProviding).self, DefaultThemeProviding())

            // Storage 指向临时目录：UI 测试不应污染用户真实数据目录，
            // 每次启动用 UUID 隔离，测试之间互不干扰。
            let storageRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("BookletMakerUITest-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
            try kernel.registerProvider((any StorageProviding).self, DefaultStorageProvider(dataRootDirectory: storageRoot))
        } catch {
            assertionFailure("Failed to setup providers: \(error)")
            print("Failed to setup providers: \(error)")
        }
    }

    private func bootPlugin() {
        do {
            try plugin.onBoot(kernel: kernel)
        } catch {
            assertionFailure("Failed to boot plugin: \(error)")
            print("Failed to boot plugin: \(error)")
        }
    }

    /// 解析各 Provider 并产出根布局。必须晚于插件启动。
    private func buildLayout() {
        guard kernel.resolveProvider((any RootViewProviding).self) != nil else {
            assertionFailure("RootViewProviding not registered")
            return
        }
        toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        rail = kernel.resolveProvider((any RailViewProviding).self)
        contentView = kernel.resolveProvider((any ContentViewProviding).self)
        layout = TestHostRootLayout(
            toolbar: toolbar,
            activityBar: activityBar,
            rail: rail,
            contentView: contentView
        )
    }

    // MARK: - Activation

    /// 激活 BookletMaker 的 ActivityBar 条目。
    ///
    /// 与真实宿主一致地走 `ActivityBarItem` 的 activation 闭包——它负责设置
    /// Rail 可见分类与可见 tab、宽度档位、工具栏标题，这些正是 UI 测试要验证的。
    func activatePlugin() {
        activityBar?.activateItem(id: "\(plugin.id).entry")
    }

    // MARK: - Test Fixtures

    /// 按启动参数向合并队列注入测试文件。
    ///
    /// 由界面测试通过 `-SeedMergeQueue 3` 传入。合并队列无法经 NSOpenPanel
    /// 填充（面板在 App 的 AX 树之外），因此改走插件的测试接缝。
    ///
    /// 必须等插件启动完成后再注入：插件在 `onBoot` 中才把 ViewModel 交给接缝，
    /// 早一步调用会拿到空队列而被静默忽略。
    func seedMergeQueueIfRequested() {
        guard BookletMakerTestHooks.isEnabled else { return }
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-SeedMergeQueue"),
              flagIndex + 1 < arguments.count,
              let count = Int(arguments[flagIndex + 1]),
              count > 0
        else { return }

        // `onAppear` 在窗口生命周期内可能触发多次；只注入一次，否则每次都会
        // 生成一批新的临时文件，去重逻辑无法识别它们是同一批，队列会翻倍。
        guard !hasSeededMergeQueue else { return }
        hasSeededMergeQueue = true

        Task { @MainActor in
            // 轮询等待插件启动：装配是异步的，而 onAppear 可能早于它完成。
            for _ in 0 ..< 100 where !BookletMakerTestHooks.isReady {
                try? await Task.sleep(for: .milliseconds(100))
            }
            do {
                let urls = try MergeQueueFixture.makePDFs(count: count)
                await BookletMakerTestHooks.seedMergeQueue(urls)
            } catch {
                // 不使用 assertionFailure：宿主 App 的断言会直接终止进程，
                // 让 XCUITest 报成「Lost connection to the application」，
                // 掩盖真正的失败原因。这里只记日志，让测试自行断言队列状态。
                NSLog("[testhost] 生成合并队列测试文件失败：%@", String(describing: error))
            }
        }
    }
}
