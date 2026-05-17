import Foundation

public extension LumiPreviewFacade {
    /// 全局预览存储配置。
    ///
    /// 管理预览系统所需的所有持久化路径（缓存、帧、共享内存等）。
    /// 宿主应用（如 `EditorPreviewPlugin`）在启动时调用 `configure(_:)` 注入自定义路径。
    ///
    /// 线程安全：通过 `NSLock` 保护内部 `_paths` 的读写，支持多线程并发访问。
    enum PreviewStorage {
        private static let lock = NSLock()

        /// 当前生效的存储路径配置。
        private nonisolated(unsafe) static var _paths: PreviewStoragePaths = .systemDefault

        /// 获取当前存储路径。
        public static var paths: PreviewStoragePaths {
            lock.lock()
            defer { lock.unlock() }
            return _paths
        }

        /// 配置存储路径。应在应用启动时调用一次。
        ///
        /// - Parameter paths: 自定义的存储路径配置。
        public static func configure(_ paths: PreviewStoragePaths) {
            lock.lock()
            _paths = paths
            lock.unlock()
        }

        #if DEBUG
        /// 重置为系统默认路径，仅供测试使用。
        static func _resetToSystemDefaultForTesting() {
            configure(.systemDefault)
        }
        #endif
    }
}
