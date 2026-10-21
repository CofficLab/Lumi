import Foundation

/// 测试专用临时目录。
///
/// ## 为什么要有它
///
/// 仓库里大量测试重复这段样板：
///
/// ```swift
/// let dir = FileManager.default.temporaryDirectory
///     .appendingPathComponent("lumi-conversation-tests-\(UUID().uuidString)", isDirectory: true)
/// try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
/// defer { try? FileManager.default.removeItem(at: dir) }
/// ```
///
/// 三行都容易写错，且**清理靠 `defer`**——一旦用例提前 `return` 或抛错，
/// 目录就会留在 `/var/folders/...` 里长期堆积。本类型让目录在一处集中创建、
/// 并提供确定性的清理时机。
///
/// ## 命名
///
/// 目录名带 `<prefix>-<UUID>` 前缀，泄漏到磁盘时能直接看出属于哪个包的哪个用途，
/// 便于排查「哪条测试留下了垃圾」。
public struct TemporaryDirectory {

    /// 目录根路径。
    public let url: URL

    /// 创建临时目录。
    ///
    /// - Parameters:
    ///   - prefix: 用途前缀，用于在磁盘上可辨识。
    /// - Throws: `FileManager` 创建目录失败。
    public init(prefix: String) throws {
        self.url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// 删除目录。
    ///
    /// - Note: 忽略「已不存在」——重复清理是合法的，清理失败同样不应让用例失败
    ///   （真正要断言的是业务行为，不是清理本身）。
    public func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    /// 在本目录下拼接子路径。
    public func appending(_ component: String, isDirectory: Bool = true) -> URL {
        url.appendingPathComponent(component, isDirectory: isDirectory)
    }

    // MARK: - Convenience

    /// 创建临时目录；抛错时包装为调用方更容易定位的上下文。
    public static func make(_ prefix: String) throws -> TemporaryDirectory {
        do {
            return try TemporaryDirectory(prefix: prefix)
        } catch {
            throw TemporaryDirectoryError.creationFailed(prefix: prefix, underlying: error)
        }
    }
}

/// 临时目录相关错误。
public enum TemporaryDirectoryError: Error, CustomStringConvertible {
    case creationFailed(prefix: String, underlying: Error)

    public var description: String {
        switch self {
        case let .creationFailed(prefix, underlying):
            return "创建测试临时目录失败（prefix: \(prefix)）：\(underlying.localizedDescription)"
        }
    }
}