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
