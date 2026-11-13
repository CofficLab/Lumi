import Foundation

/// 终端工作目录校验
///
/// SwiftTerm 1.20.0 的 `PseudoTerminalHelpers.fork(andExec:)` 会忽略 `chdir` 的返回值，
/// 工作目录无效时 shell 仍会在 Lumi 当前目录启动并被误报为已连接（#174）。
/// 这里在启动进程前先校验目录，失败时让会话保持未连接并暴露可识别的错误。
public enum TerminalWorkingDirectory {
    // MARK: - Errors

    public enum Error: Swift.Error, LocalizedError {
        case notFound(String)
        case notDirectory(String)
        case notAccessible(String)

        public var errorDescription: String? {
            switch self {
            case .notFound(let path):
                return "Working directory does not exist: \(path)"
            case .notDirectory(let path):
                return "Working directory is not a directory: \(path)"
            case .notAccessible(let path):
                return "Working directory is not accessible: \(path)"
            }
        }
    }

    // MARK: - Validation

    /// 校验工作目录是否可用于启动 shell。
    ///
    /// - Parameter path: 工作目录；`nil` 或空串表示继承当前目录，视为合法。
    /// - Throws: 目录不存在、不是目录或不可进入（缺少搜索权限）时抛出 `Error`。
    public static func validate(_ path: String?) throws {
        guard let path, !path.isEmpty else { return }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw Error.notFound(path)
        }
        guard isDirectory.boolValue else {
            throw Error.notDirectory(path)
        }
        // chdir 需要目录的搜索（执行）权限；缺少时进入会失败。
        guard fileManager.isExecutableFile(atPath: path) else {
            throw Error.notAccessible(path)
        }
    }
}