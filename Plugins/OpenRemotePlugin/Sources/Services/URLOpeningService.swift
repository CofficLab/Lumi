import AppKit
import Foundation
import SuperLogKit
import os

/// URL 打开服务
///
/// 封装 `NSWorkspace.shared.open` 这一 AppKit 副作用，让视图层不必直接接触
/// `NSWorkspace`，便于测试时替换为桩实现。
///
/// ## 线程安全
///
/// `NSWorkspace.shared` 是线程安全的；本服务无共享可变状态。
public final class URLOpeningService: @unchecked Sendable, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.open-remote.url-opener"
    )
    public nonisolated static let verbose: Bool = false
    public nonisolated static let emoji = "🔗"

    public static let shared = URLOpeningService()

    private init() {}

    /// 用系统默认浏览器打开 URL。
    ///
    /// - Parameter url: 要打开的 URL
    /// - Returns: 是否成功交给系统处理（失败原因写入日志）
    @discardableResult
    public func openInBrowser(_ url: URL) -> Bool {
        Self.logger.info("\(Self.t)openInBrowser\(self.r("打开 \(url.absoluteString)"))")
        let ok = NSWorkspace.shared.open(url)
        if !ok && Self.verbose {
            Self.logger.error("\(Self.t)openInBrowser 失败\(self.r("NSWorkspace.open 返回 false"))")
        }
        return ok
    }
}