import Foundation

public extension LumiPreviewFacade {
    /// Global preview storage configuration. Host apps (e.g. EditorPreviewPlugin) call `configure` at launch.
    enum PreviewStorage {
        private static let lock = NSLock()
        private nonisolated(unsafe) static var _paths: PreviewStoragePaths = .systemDefault

        public static var paths: PreviewStoragePaths {
            lock.lock()
            defer { lock.unlock() }
            return _paths
        }

        public static func configure(_ paths: PreviewStoragePaths) {
            lock.lock()
            _paths = paths
            lock.unlock()
        }

        #if DEBUG
        static func _resetToSystemDefaultForTesting() {
            configure(.systemDefault)
        }
        #endif
    }
}
