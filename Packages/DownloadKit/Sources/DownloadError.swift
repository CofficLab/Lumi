import Foundation

/// DownloadKit 错误类型
public enum DownloadError: LocalizedError, Equatable {
    /// URL 无效
    case invalidURL(String)
    /// HTTP 错误
    case httpError(Int)
    /// 网络连接失败
    case networkError(String)
    /// 文件不存在
    case fileNotFound(String)
    /// 文件大小不匹配
    case sizeMismatch(expected: Int64, actual: Int64)
    /// 文件为空
    case emptyFile(String)
    /// 无法创建目录
    case cannotCreateDirectory(String)
    /// 无法写入文件
    case cannotWriteFile(String)
    /// 下载已取消
    case cancelled
    /// 未知错误
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "无效的 URL: \(url)"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .fileNotFound(let path):
            return "文件不存在: \(path)"
        case .sizeMismatch(let expected, let actual):
            return "文件大小不匹配: 期望 \(expected) 字节, 实际 \(actual) 字节"
        case .emptyFile(let path):
            return "文件为空: \(path)"
        case .cannotCreateDirectory(let path):
            return "无法创建目录: \(path)"
        case .cannotWriteFile(let path):
            return "无法写入文件: \(path)"
        case .cancelled:
            return "下载已取消"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}
