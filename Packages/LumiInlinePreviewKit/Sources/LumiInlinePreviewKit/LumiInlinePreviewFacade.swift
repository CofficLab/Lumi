import Foundation
import os

/// 命名空间外壳，所有公开类型都嵌套在此 enum 下，避免与 `LumiPreviewKit` 命名冲突。
public enum LumiInlinePreviewFacade {
    /// 包内共享 Logger，供 DemoSurfaceFactory / PreviewSurfaceCanvas 等使用。
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "LumiInlinePreviewKit")
    /// 是否启用日志输出，由宿主 App 的插件 verbose 控制。
    nonisolated(unsafe) public static var verbose: Bool = false
}
