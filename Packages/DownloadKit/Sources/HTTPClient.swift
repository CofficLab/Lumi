import Foundation

/// HTTP 客户端协议，用于抽象下载逻辑
public protocol HTTPClient: Sendable {
    /// 下载文件到指定位置
    /// - Parameters:
    ///   - url: 远程 URL
    ///   - destination: 本地目标路径
    ///   - resumeData: 断点续传数据
    ///   - progressHandler: 进度回调
    /// - Returns: 下载结果
    func download(
        from url: URL,
        to destination: URL,
        resumeData: Data?,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void
    ) async throws -> Data?
}

/// 默认 HTTP 客户端实现，基于 URLSession
public final class DefaultHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession
    private let delegate: DownloadDelegate
    
    public init(configuration: URLSessionConfiguration = .default) {
        self.delegate = DownloadDelegate()
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    public func download(
        from url: URL,
        to destination: URL,
        resumeData: Data?,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void
    ) async throws -> Data? {
        let task: URLSessionDownloadTask
        
        if let resumeData {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: url)
        }
        
        delegate.setProgressHandler(for: task.taskIdentifier, handler: progressHandler)
        
        return try await withCheckedThrowingContinuation { continuation in
            delegate.setContinuation(for: task.taskIdentifier, continuation: continuation)
            task.resume()
        }
    }
}

/// URLSession 下载代理
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuations: [Int: CheckedContinuation<Data?, Error>] = [:]
    private var progressHandlers: [Int: @Sendable (Int64, Int64?) -> Void] = [:]
    private let lock = NSLock()
    
    func setContinuation(for taskId: Int, continuation: CheckedContinuation<Data?, Error>) {
        lock.lock()
        continuations[taskId] = continuation
        lock.unlock()
    }
    
    func setProgressHandler(for taskId: Int, handler: @Sendable @escaping (Int64, Int64?) -> Void) {
        lock.lock()
        progressHandlers[taskId] = handler
        lock.unlock()
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskId = downloadTask.taskIdentifier
        lock.lock()
        let handler = progressHandlers[taskId]
        lock.unlock()
        
        let totalBytes = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        handler?(totalBytesWritten, totalBytes)
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier
        
        lock.lock()
        let continuation = continuations.removeValue(forKey: taskId)
        progressHandlers.removeValue(forKey: taskId)
        lock.unlock()
        
        // 获取目标路径（从 downloadTask 的原始请求 URL 推断或使用临时文件数据）
        do {
            let data = try Data(contentsOf: location)
            continuation?.resume(returning: data)
        } catch {
            continuation?.resume(throwing: error)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let taskId = task.taskIdentifier
        
        lock.lock()
        let continuation = continuations.removeValue(forKey: taskId)
        progressHandlers.removeValue(forKey: taskId)
        lock.unlock()
        
        if let error {
            continuation?.resume(throwing: error)
        }
    }
}
