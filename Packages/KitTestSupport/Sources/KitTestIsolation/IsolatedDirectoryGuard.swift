import Foundation

/// 测试环境下「目录未注入」的兜底目录守卫。
///
/// ## 背景：为什么生产代码不能直接回退真实目录
///
/// 插件的运行时目录（如 `AppUpdateRuntime.settingsDirectory()`）由 `onBoot`
/// 从内核 `StorageProviding` 注入。为了兼容「插件尚未 boot 的极早期访问」，
/// 各 `*Runtime` 都保留了一个回退到 `~/Library/Application Support/...`
/// 的存根路径。
///
/// 问题在于：**测试进程也走同一个回退分支**。一旦某个测试忘记注入目录，
/// 它不会失败，而是安静地读写开发者本机的真实数据目录。后果有两个方向：
///
/// - 污染真实数据（测试往用户目录写垃圾）；
/// - 被真实数据影响（目录里残留的历史记录让断言随机失败）。
///
/// 这类失败极难归因——报错指向业务断言，真实原因却在几百行之外的路径拼接。
///
/// ## 契约
///
/// 在测试进程里，目录守卫**不返回真实目录，而是直接失败**。
/// 让「忘记注入」在第一次发生时就以明确的错误信息终止，而不是伪装成通过。
///
/// - Note: `fatalError` 而非 `throw`：这些访问点在 `static var` 属性初始化器
///   与 `onBoot` 里，不在错误可传播的上下文中；而且**静默降级才是真正的危害**，
///   崩溃反而是最诚实的信号。若某个访问点确实可恢复，应当显式注入临时目录，
///   而不是依赖回退。
/// - Note: 需要在**不崩溃**的前提下验证该契约时，用 `resolve(injected:...)`
///   ——它返回判定结果而不终止进程。
public enum IsolatedDirectoryGuard {

    /// 目录解析结果。
    public enum Outcome {
        /// 允许使用该目录。
        case resolved(URL)
        /// 测试环境下拒绝回退到真实目录。
        case refused(reason: String)
    }

    // MARK: - 解析（不终止进程）

    /// 解析目录：已注入则用它；未注入时生产环境回退，测试环境拒绝。
    ///
    /// - Parameters:
    ///   - injected: `onBoot` 注入的目录，可能为 `nil`。
    ///   - owner: 目录归属者的类型名（插件名），用于错误信息定位。
    ///   - accessor: 访问入口的符号名，用于错误信息定位。
    ///   - fallback: 仅生产环境使用的真实目录。
    public static func resolve(
        injected: URL?,
        owner: String,
        accessor: String,
        fallback: () -> URL
    ) -> Outcome {
        if let injected { return .resolved(injected) }
        guard TestProcessDetector.isTestProcess else {
            return .resolved(fallback())
        }
        return .refused(reason: refusalMessage(owner: owner, accessor: accessor))
    }

    /// 解析目录：已注入则用它；未注入时生产环境回退，测试环境拒绝。
    ///
    /// 与 `resolve(injected:owner:accessor:fallback:)` 的区别：此处在拒绝时
    /// 直接终止进程。供生产代码的目录访问点使用。
    public static func directory(
        injected: URL?,
        owner: String,
        accessor: String,
        fallback: () -> URL
    ) -> URL {
        switch resolve(injected: injected, owner: owner, accessor: accessor, fallback: fallback) {
        case let .resolved(url):
            return url
        case let .refused(reason):
            fatalError(reason)
        }
    }

    // MARK: - 消息

    /// 拒绝原因文本。
    public static func refusalMessage(owner: String, accessor: String) -> String {
        """
        [TestIsolation] \(owner).\(accessor) 在测试进程中被调用，但运行时目录从未注入。
        测试不得读写本机真实数据目录（否则会污染开发者数据，并让断言受历史残留影响）。

        修复方式：用临时目录注入，而不是依赖回退。
          // 1) 有 Runtime.configure(...) 的插件：
          let dir = try makeTemporaryDirectory()   // KitTestSupport 提供
          defer { try? FileManager.default.removeItem(at: dir) }
          XxxRuntime.configure(settingsDirectory: dir)

          // 2) 需要真实持久化行为（SQLite / SwiftData / 迁移）的插件：
          //    用临时目录作为 StorageProviding 的根，目录形状与生产一致：
          let root = try makeTemporaryDirectory()
          let storage = DefaultStorageProvider(dataRootDirectory: root)
          try kernel.registerProvider((any StorageProviding).self, storage)
        """
    }
}