import AppKit

/// 独立预览宿主程序入口。
///
/// 使用后台线程处理 stdin/stdout JSON 通信，让主线程保留给 AppKit run loop。
let host = StdioPreviewHost()
host.run()
