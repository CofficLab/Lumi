import Foundation

/// 处理 `DepthWarningVM.depthWarning` 的变化副作用。
enum DepthWarningStateHandler {
    static func handle() {
        AppLogger.core.info("onDepthWarningChanged")
    }
}

