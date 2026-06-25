import Foundation

/// HTTP 客户端协议，用于抽象下载逻辑
public protocol HTTPClient: Sendable {
    /// 下载文件到指定位置（支持字节级断点续传）。
    ///
    /// 采用 HTTP `Range` 请求 + 流式追加写入：当目标文件已存在 `existingBytes` 字节时，
    /// 以 `Range: bytes=<existingBytes>-` 续传剩余部分并追加到文件末尾，常驻内存恒定，
    /// 不再把整份文件读进内存。这是常见下载软件的续传做法。
    ///
    /// - Parameters:
    ///   - url: 远程 URL
    ///   - destination: 本地目标路径（已存在的部分文件将被续传追加）
    ///   - existingBytes: 目标文件已下载的字节数（续传起点）；0 表示全新下载
    ///   - progressHandler: 进度回调。`downloadedBytes` 为累计值（含续传部分），即
    ///     `existingBytes + 本次已写字节`，便于上层直接计算整体进度
    ///   - onCancelled: 取消回调（流式写入已即时落盘，无需 resume data，参数固定为 nil）
    /// - Returns: 本次新写入的字节数（不含 existingBytes）；nil 表示未写入
    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64?
}

/// 默认 HTTP 客户端实现，基于 URLSession 流式下载 + Range 续传
public final class DefaultHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    public init(configuration: URLSessionConfiguration = .default) {
        self.session = URLSession(configuration: configuration)
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        var request = URLRequest(url: url)
        // 断点续传：已有字节时用 Range 请求剩余部分。
        if existingBytes > 0 {
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
        }

        // withTaskCancellationHandler：外层 Task 取消时取消底层 URLSession data task，
        // 否则「暂停」后网络请求会一直跑到自然结束。流式写入已即时落盘，取消即续传点。
        let (bytes, response) = try await withTaskCancellationHandler {
            try await session.bytes(for: request)
        } onCancel: {
            // bytes(for:) 返回的 AsyncSequence 由底层 task 驱动；取消 Task 后
            // 迭代会抛 CancellationError 自然退出，已写入字节已在磁盘上。
        }

        // 判断服务器是否支持续传：206 Partial Content 表示从断点续传；
        // 200 表示服务器忽略了 Range（或全新请求），必须从 0 重写，否则拼接错乱。
        let httpResp = response as? HTTPURLResponse
        let statusCode = httpResp?.statusCode ?? 0

        // 检查 HTTP 状态码：非 200/206 表示服务器错误（如 403 Forbidden、404 Not Found）。
        // LFS 文件重定向失败时，HuggingFace 可能返回 HTML 错误页面而非文件内容，
        // 若不检查状态码，错误页面会被写入磁盘伪装成模型文件。
        guard statusCode == 200 || statusCode == 206 else {
            throw DownloadError.httpError(statusCode)
        }

        let supportsResume = statusCode == 206

        // Content-Range: bytes <start>-<end>/<total> 或 Content-Length 给出本次剩余大小。
        // 续传时 totalBytesExpected = existingBytes + 本次长度（用于进度分母）。
        var resumeBaseBytes: Int64 = 0
        var remainingTotal: Int64? = nil

        if supportsResume {
            resumeBaseBytes = existingBytes
            // Content-Range 形如 "bytes 500-999/2000"，末段是完整文件总大小
            if let contentRange = httpResp?.value(forHTTPHeaderField: "Content-Range"),
               let total = parseContentRangeTotal(contentRange) {
                remainingTotal = total - existingBytes
            } else if let len = httpResp?.value(forHTTPHeaderField: "Content-Length"),
                      let n = Int64(len) {
                remainingTotal = n
            }
        } else {
            // 全新下载：若本地有残留部分文件，截断从头写（服务器返回完整内容）
            if existingBytes > 0 {
                try? FileManager.default.removeItem(at: destination)
            }
            if let len = httpResp?.value(forHTTPHeaderField: "Content-Length"),
               let n = Int64(len) {
                remainingTotal = n
            }
        }

        // 流式追加写入：续传时 seek 到末尾追加；全新下载时覆盖写。
        // 确保目标目录存在
        let dir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let writeMode: StreamingWriteMode = supportsResume ? .append : .replace
        let handle = try FileHandle.openForStreamingWrite(at: destination, mode: writeMode)
        defer { try? handle.close() }

        var writtenThisSession: Int64 = 0
        let bufferSize = 64 * 1024  // 64KB 缓冲，常驻内存恒定
        var buffer = Data()
        buffer.reserveCapacity(bufferSize)

        do {
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= bufferSize {
                    try handle.write(contentsOf: buffer)
                    writtenThisSession += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    progressHandler(resumeBaseBytes + writtenThisSession, remainingTotal.map { resumeBaseBytes + $0 })
                }
            }
            // flush 残余
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
                writtenThisSession += Int64(buffer.count)
                progressHandler(resumeBaseBytes + writtenThisSession, remainingTotal.map { resumeBaseBytes + $0 })
            }
        } catch {
            // 取消（Task cancelled）或网络错误：已写入字节已在磁盘，直接抛出，
            // 上层据磁盘文件大小下次续传。
            throw error
        }

        return writtenThisSession
    }

    /// 解析 `Content-Range: bytes <start>-<end>/<total>` 中的 total；无法解析返回 nil。
    private func parseContentRangeTotal(_ value: String) -> Int64? {
        // 形如 "bytes 500-999/2000" 或 "bytes 500-999/*"
        guard let slash = value.lastIndex(of: "/") else { return nil }
        let totalPart = String(value[value.index(after: slash)...])
        return Int64(totalPart)
    }
}

/// 流式写入文件的打开模式
fileprivate enum StreamingWriteMode {
    /// 续传：打开已存在文件并 seek 到末尾追加
    case append
    /// 全新：创建/截断文件从头写
    case replace
}

fileprivate extension FileHandle {
    static func openForStreamingWrite(at url: URL, mode: StreamingWriteMode) throws -> FileHandle {
        switch mode {
        case .append:
            // 续传要求文件已存在（部分文件）；若不存在则视为全新
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                return handle
            } else {
                FileManager.default.createFile(atPath: url.path, contents: nil)
                return try FileHandle(forWritingTo: url)
            }
        case .replace:
            // 覆盖写：先删除旧文件再创建，保证从头开始
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: url.path, contents: nil)
            return try FileHandle(forWritingTo: url)
        }
    }
}
