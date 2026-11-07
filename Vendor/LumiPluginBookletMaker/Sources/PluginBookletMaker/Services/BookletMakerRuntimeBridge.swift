import Foundation

// MARK: - Booklet Maker Runtime Bridge

/// Holds plugin-wide runtime state that is shared between the boot
/// sequence (which has access to the kernel) and the view model (which
/// does not). Mirrors ``ImageToPDFRuntimeBridge``.
enum BookletMakerRuntimeBridge {

    /// Plugin data directory injected by ``BookletMakerPlugin/onBoot``.
    nonisolated(unsafe) static var directoryURL: URL?
}

// MARK: - Test Seams

/// 供宿主侧 UI 测试注入的接缝。
///
/// ## 为什么需要它
///
/// 合并工具的队列（上移 / 下移 / 删除、顺序是否影响导出结果）在真实使用时
/// 由用户在 `NSOpenPanel` 里挑文件填充。但 `NSOpenPanel.runModal()` 在 App 的
/// 辅助功能树之外运行，XCUITest 既无法可靠驱动它，也无法断言其结果——于是
/// 「队列非空时的行为」整个成为测试盲区。
///
/// ## 边界
///
/// 仅在 `BOOKLET_MAKER_UI_TESTING=1` 时生效，且只提供**只读**的当前状态观察
/// 与**测试用**的注入入口：
/// - 宿主不能借它读取用户的文档内容，只有队列规模与页数这类插件本就在界面上
///   展示的信息；
/// - 注入的文件 URL 会被插件按既有逻辑重新走一遍检查与去重，
///   不绕过任何校验，因此注入点测到的仍是真实的加载路径。
///
/// 生产路径完全不经过这里——没有环境变量时所有入口都是空实现。
@MainActor
public enum BookletMakerTestHooks {

    /// 宿主是否显式打开了测试接缝。
    ///
    /// 只读常量：开关由进程环境变量决定，运行期不可改。
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["BOOKLET_MAKER_UI_TESTING"] == "1"
    }

    /// 插件是否已把 ViewModel 交给接缝。
    ///
    /// 装配是异步的，宿主可能早于插件启动就尝试注入；用这个标志等待，
    /// 避免注入被静默丢弃。
    public static var isReady: Bool {
        isEnabled && viewModel != nil
    }

    /// 界面测试时面板的预选目录。
    ///
    /// 必须落在宿主自己的临时目录里，而不是 `NSTemporaryDirectory()`：宿主
    /// 在测试模式下**不开沙盒**，系统临时目录会解析到用户可见位置，导出
    /// 产物会直接掉进用户文件夹，而 XCUITest runner 有沙盒、无权清理。
    nonisolated(unsafe) static var exportDirectoryURL: URL?

    /// 插件启动时把自己持有的 ViewModel 交出来，供测试注入队列。
    ///
    /// 与插件其余部分一样是插件级单例：rail 与内容区共享同一份配置状态，
    /// 因此注入后两侧看到的是同一份数据。
    nonisolated(unsafe) static weak var viewModel: BookletMakerViewModel?

    /// 注入测试文件到合并队列。
    ///
    /// 复用 `loadMergePDFs(_:appending:)`，与用户选择文件走同一条路径：
    /// 同样会做 PDF 可读性检查、页数统计与去重。
    ///
    /// - Parameter urls: 待加入队列的文件 URL。
    public static func seedMergeQueue(_ urls: [URL]) async {
        guard isEnabled, let viewModel else { return }
        await viewModel.loadMergePDFs(urls, appending: true)
    }
}
