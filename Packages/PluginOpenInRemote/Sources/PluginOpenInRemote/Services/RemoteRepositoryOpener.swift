import AppKit
import Foundation

/// 在默认浏览器中打开项目远程仓库的网页地址。
///
/// 只做两件事：解析 Web 链接、交给系统打开。不涉及任何写操作，
/// 因此风险等级为「低」。
enum RemoteRepositoryOpener {
    /// 用系统默认浏览器打开链接。
    ///
    /// - Parameter url: 目标链接。
    /// - Returns: 打开成功返回 `true`；系统拒绝打开时返回 `false`。
    @MainActor
    static func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
