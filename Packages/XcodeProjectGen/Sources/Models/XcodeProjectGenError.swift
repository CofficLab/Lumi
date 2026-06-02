import Foundation

/// XcodeProjectGen 模块的公共错误类型。
public enum XcodeProjectGenError: LocalizedError, Sendable {
    /// 项目根目录不存在。
    case projectRootNotFound(String)
    /// 源文件目录不存在。
    case sourcesDirectoryNotFound(String)
    /// 指定的 Target 未找到。
    case targetNotFound(String)
    /// 写出 .xcodeproj 失败。
    case writeFailed(String)
    /// Spec 校验失败。
    case validationError(String)
    /// 文件扫描失败。
    case scanFailed(String)

    public var errorDescription: String? {
        switch self {
        case .projectRootNotFound(let path):
            return "Project root directory not found: \(path)"
        case .sourcesDirectoryNotFound(let path):
            return "Sources directory not found: \(path)"
        case .targetNotFound(let name):
            return "Target '\(name)' not found in spec"
        case .writeFailed(let message):
            return "Failed to write .xcodeproj: \(message)"
        case .validationError(let message):
            return "Spec validation failed: \(message)"
        case .scanFailed(let message):
            return "File scan failed: \(message)"
        }
    }
}
