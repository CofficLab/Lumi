import Foundation

/// 下载任务描述
public struct DownloadTask: Sendable, Identifiable, Equatable {
    /// 任务唯一标识
    public let id: String
    /// 远程 URL
    public let url: URL
    /// 本地目标路径
    public let destination: URL
    /// 期望的文件大小（可选）
    public let expectedSize: Int64?
    /// HTTP 请求头
    public let headers: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        url: URL,
        destination: URL,
        expectedSize: Int64? = nil,
        headers: [String: String] = [:]
    ) {
        self.id = id
        self.url = url
        self.destination = destination
        self.expectedSize = expectedSize
        self.headers = headers
    }
    
    /// 未完成文件路径
    public var incompleteURL: URL {
        destination.appendingPathExtension("incomplete")
    }
}

/// 下载任务状态
public enum DownloadTaskState: Sendable, Equatable {
    case pending
    case downloading(progress: DownloadProgress)
    case completed
    case failed(DownloadError)
    case cancelled

    /// 是否处于终态（不会再变化）。
    ///
    /// 用于阻止滞后的进度回调把已取消/失败/完成的状态覆盖回 `.downloading`，
    /// 从而让取消后能重新下载同一 id 的任务（暂停→恢复场景）。
    public var isFinal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .pending, .downloading:
            return false
        }
    }

    public static func == (lhs: DownloadTaskState, rhs: DownloadTaskState) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): return true
        case (.downloading(let l), .downloading(let r)): return l == r
        case (.completed, .completed): return true
        case (.failed(let l), .failed(let r)): return l == r
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
}
