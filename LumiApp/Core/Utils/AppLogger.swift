import Foundation
import os

enum AppLogger {
    /// 全局日志开关。设为 false 时 AppLogger 日志仍然写入系统日志，
    /// 但可通过 Console.app 按 subsystem 过滤。
    /// 设为 true 时所有日志正常输出。
    nonisolated(unsafe) static var verbose: Bool = false

    static let core = os.Logger(subsystem: "com.coffic.lumi", category: "core")
    static let layout = os.Logger(subsystem: "com.coffic.lumi", category: "layout")
}
