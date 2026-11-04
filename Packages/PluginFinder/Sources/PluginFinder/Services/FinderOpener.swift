import AppKit
import Foundation

/// 在 Finder 中打开文件夹的服务。
///
/// 抽象出来是为了让「路径是否合法」「目标是否存在」这类判定可以被单元测试覆盖，
/// 而不必真的唤起 Finder。
@MainActor
enum FinderOpener {
    /// 打开目标文件夹。
    ///
    /// - Parameter path: 目标文件夹的绝对路径。
    /// - Returns: 打开成功返回 `true`；路径非法或不存在返回 `false`。
    @discardableResult
    static func open(path: String) -> Bool {
        guard let url = validatedURL(for: path) else { return false }
        return NSWorkspace.shared.open(url)
    }

    /// 校验路径并生成可打开的 URL。
    ///
    /// 只有真实存在的目录才允许打开——避免把 Finder 指向一个不存在的路径，
    /// 那只会弹出一个空窗口或一条报错。
    static func validatedURL(for path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let url = URL(fileURLWithPath: trimmed)
        guard url.isFileURL else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return url
    }
}
