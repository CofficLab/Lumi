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
    ///   - maxBytesPerSecond: 下载速率限制（字节/秒）。`nil` 表示不限速
    ///   - progressHandler: 进度回调。`downloadedBytes` 为累计值（含续传部分），即
    ///     `existingBytes + 本次已写字节`，便于上层直接计算整体进度
    ///   - onCancelled: 取消回调（流式写入已即时落盘，无需 resume data，参数固定为 nil）
    /// - Returns: 本次新写入的字节数（不含 existingBytes）；nil 表示未写入
    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64?

    /// 带自定义请求头的下载（如 Authorization）。
    ///
    /// 协议要求 + 默认实现（见下方 extension）：默认实现丢弃 `headers` 并退回无请求头
    /// 版本，既有 conformer 无需改动即可继续编译；`DefaultHTTPClient` 覆盖此方法真正
    /// 发送请求头。注意必须是协议要求而非纯扩展方法，否则经由 existential 调用时
    /// 不会动态派发到 conformer 的覆盖实现。
    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        headers: [String: String],
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64?
}

// MARK: - Backward-Compatible Default

public extension HTTPClient {
    /// 向后兼容的便捷方法，不限速
    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        try await download(
            from: url,
            to: destination,
            existingBytes: existingBytes,
            maxBytesPerSecond: nil,
            progressHandler: progressHandler,
            onCancelled: onCancelled
        )
    }

    /// `download(...:headers:)` 协议要求的默认实现：丢弃请求头，退回无请求头版本，
    /// 保证未覆盖该要求的既有 conformer 行为不变。
    func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        headers: [String: String],
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        try await download(
            from: url,
            to: destination,
            existingBytes: existingBytes,
            maxBytesPerSecond: maxBytesPerSecond,
            progressHandler: progressHandler,
            onCancelled: onCancelled
        )
    }
}

/// 默认 HTTP 客户端实现，基于 URLSession 流式下载 + Range 续传
public final class DefaultHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    /// 可选的共享限速器。
    ///
    /// 注入后，所有下载统一走该限速器（`maxBytesPerSecond` 参数将被忽略），从而支持
    /// 运行时动态调整限速（用户「下载到一半改限速」时无需重启下载任务）。
    /// 为 `nil` 时退回每次下载用 `maxBytesPerSecond` 创建临时限速器的旧行为。
    private let rateLimiter: RateLimiter?

    public init(configuration: URLSessionConfiguration = .default, rateLimiter: RateLimiter? = nil) {
        self.session = URLSession(configuration: configuration)
        self.rateLimiter = rateLimiter
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        try await download(
            from: url,
            to: destination,
            existingBytes: existingBytes,
            maxBytesPerSecond: maxBytesPerSecond,
            headers: [:],
            progressHandler: progressHandler,
            onCancelled: onCancelled
        )
    }

    /// 带自定义请求头的下载（如 Authorization）；其余行为与无请求头版本一致。
    public func download(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        headers: [String: String],
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void
    ) async throws -> Int64? {
        try await performDownload(
            from: url,
            to: destination,
            existingBytes: existingBytes,
            maxBytesPerSecond: maxBytesPerSecond,
            headers: headers,
            progressHandler: progressHandler,
            onCancelled: onCancelled,
            allowRestart: true
        )
    }

    /// 实际下载实现。`allowRestart` 保证「远程版本变化后从头重下」最多发生一次。
    private func performDownload(
        from url: URL,
        to destination: URL,
        existingBytes: Int64,
        maxBytesPerSecond: Int?,
        headers: [String: String],
        progressHandler: @Sendable @escaping (Int64, Int64?) -> Void,
        onCancelled: @Sendable @escaping (Data?) -> Void,
        allowRestart: Bool
    ) async throws -> Int64? {
        // 注入了共享限速器则统一使用它（忽略 maxBytesPerSecond，以支持运行时动态调整）；
        // 否则退回旧行为：按本次 maxBytesPerSecond 创建临时限速器。
        let limiter = rateLimiter ?? RateLimiter(bytesPerSecond: maxBytesPerSecond)

        // 续传必须带上首次响应保存的 validator：同一 URL 的远程内容可能在两次
        // 请求之间变化，仅凭本地字节数续传会把新旧版本拼成损坏文件。
        // 没有可用的 validator 时宁可从头下载，也不做不安全的续传。
        let storedValidator = ResumeValidatorStore.load(for: destination, url: url)
        let canResume = existingBytes > 0 && storedValidator?.ifRangeValue != nil

        var request = URLRequest(url: url)
        // 自定义请求头（如 Authorization）
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        // 断点续传：已有字节且 validator 可用时用 Range + If-Range 请求剩余部分。
        // 远程内容变化时，符合规范的服务器会忽略 Range 返回 200 完整内容。
        if canResume {
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
            if let ifRange = storedValidator?.ifRangeValue {
                request.setValue(ifRange, forHTTPHeaderField: "If-Range")
            }
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

        // 未请求 Range 却收到 206（或没有可信 validator 却要续传）时，无法确认
        // 本地前缀与本次内容同源，直接报错而不是冒险拼接。
        if supportsResume && !canResume {
            throw DownloadError.unknown("服务器返回了无法安全续传的部分内容")
        }

        let responseValidator = ResumeValidator(response: httpResp)

        // 部分服务器会忽略 If-Range 直接返回 206。此时用响应头里的 validator
        // 与本地记录对比；不一致说明远程内容已变，放弃本次续传从头下载。
        if supportsResume,
           let storedValidator,
           let responseValidator,
           !responseValidator.matches(storedValidator) {
            guard allowRestart else {
                throw DownloadError.unknown("远程文件已变化，无法安全续传")
            }
            return try await performDownload(
                from: url,
                to: destination,
                existingBytes: 0,
                maxBytesPerSecond: maxBytesPerSecond,
                headers: headers,
                progressHandler: progressHandler,
                onCancelled: onCancelled,
                allowRestart: false
            )
        }

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
            // 全新下载：服务器返回完整内容，remainingTotal 直接取 Content-Length。
            // 目标已有文件时不会在这里删除它，见下方的临时文件替换逻辑。
            if let len = httpResp?.value(forHTTPHeaderField: "Content-Length"),
               let n = Int64(len) {
                remainingTotal = n
            }
        }

        // 服务器忽略 Range（返回 200）且目标已有文件时，不能删除旧文件后直接写
        // 最终路径：传输中途失败会把用户原有的成品变成半截文件。改为先写同目录
        // 临时文件，完整收完后再原子替换目标；失败时旧文件保持可用。
        let replacementURL = (!supportsResume && existingBytes > 0)
            ? Self.temporaryReplacementURL(for: destination)
            : nil
        let writeURL = replacementURL ?? destination

        // 流式追加写入：续传时 seek 到末尾追加；全新下载时覆盖写。
        // 确保目标目录存在
        let dir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let writeMode: StreamingWriteMode = supportsResume ? .append : .replace
        let handle = try FileHandle.openForStreamingWrite(at: writeURL, mode: writeMode)
        defer { try? handle.close() }

        // 直接写目标路径时，先把本次响应 validator 持久化：若传输中断，
        // 下次重试才能用 If-Range 确认前缀与远程内容同源。
        // 替换下载写的是临时文件，不能覆盖旧文件对应的 validator。
        if replacementURL == nil, let responseValidator {
            ResumeValidatorStore.save(responseValidator, for: destination, url: url)
        }

        var writtenThisSession: Int64 = 0
        let bufferSize = 64 * 1024  // 64KB 缓冲，常驻内存恒定
        var buffer = Data()
        buffer.reserveCapacity(bufferSize)

        do {
            // 按缓冲区批次限速：每填满一次 buffer 统一申请一次令牌，避免逐字节锁竞争
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= bufferSize {
                    try await limiter.acquire(bytes: buffer.count)
                    try handle.write(contentsOf: buffer)
                    writtenThisSession += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    progressHandler(resumeBaseBytes + writtenThisSession, remainingTotal.map { resumeBaseBytes + $0 })
                }
            }
            // flush 残余：写入前申请剩余字节令牌
            if !buffer.isEmpty {
                try await limiter.acquire(bytes: buffer.count)
                try handle.write(contentsOf: buffer)
                writtenThisSession += Int64(buffer.count)
                progressHandler(resumeBaseBytes + writtenThisSession, remainingTotal.map { resumeBaseBytes + $0 })
            }
        } catch {
            // 取消（Task cancelled）或网络错误：把缓冲区里已接收的字节尽量落盘，
            // 否则最多 64KB 的进度会白丢，续传起点也会随之缩水。
            if !buffer.isEmpty {
                try? handle.write(contentsOf: buffer)
                writtenThisSession += Int64(buffer.count)
            }
            // 替换下载则丢弃临时文件，保留目标路径上的旧文件。
            if let replacementURL {
                try? FileManager.default.removeItem(at: replacementURL)
            }
            throw error
        }

        // 替换下载：确认收到完整内容后原子替换目标，避免半截文件覆盖旧成品。
        if let replacementURL {
            try? handle.close()
            do {
                if let expected = remainingTotal, writtenThisSession != expected {
                    throw DownloadError.networkError(
                        "下载不完整：期望 \(expected) 字节，实际收到 \(writtenThisSession) 字节"
                    )
                }
                if FileManager.default.fileExists(atPath: destination.path) {
                    _ = try FileManager.default.replaceItemAt(destination, withItemAt: replacementURL)
                } else {
                    try FileManager.default.moveItem(at: replacementURL, to: destination)
                }
            } catch {
                try? FileManager.default.removeItem(at: replacementURL)
                throw error
            }
        }

        // 下载完整结束，validator 不再需要：避免后续把已完成文件当作部分文件续传。
        ResumeValidatorStore.remove(for: destination)

        return writtenThisSession
    }

    /// 替换下载的临时文件路径：与目标同目录，保证 `replaceItemAt` 在同卷内原子完成。
    private static func temporaryReplacementURL(for destination: URL) -> URL {
        destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).download-\(UUID().uuidString)")
    }

    /// 解析 `Content-Range: bytes <start>-<end>/<total>` 中的 total；无法解析返回 nil。
    private func parseContentRangeTotal(_ value: String) -> Int64? {
        // 形如 "bytes 500-999/2000" 或 "bytes 500-999/*"
        guard let slash = value.lastIndex(of: "/") else { return nil }
        let totalPart = String(value[value.index(after: slash)...])
        return Int64(totalPart)
    }
}

/// 远程内容版本标识（ETag 优先，其次是 Last-Modified）。
///
/// 续传前用 `If-Range` 携带它：远程内容已变化时服务器会返回完整内容而不是 206，
/// 从而避免把新旧版本拼成损坏文件。
struct ResumeValidator: Equatable, Sendable {
    let etag: String?
    let lastModified: String?

    /// `If-Range` 只接受一个值，ETag 更精确，优先使用。
    var ifRangeValue: String? { etag ?? lastModified }

    init(etag: String?, lastModified: String?) {
        self.etag = etag
        self.lastModified = lastModified
    }

    init?(response: HTTPURLResponse?) {
        let etag = response?.value(forHTTPHeaderField: "ETag")
        let lastModified = response?.value(forHTTPHeaderField: "Last-Modified")
        guard etag != nil || lastModified != nil else { return nil }
        self.init(etag: etag, lastModified: lastModified)
    }

    /// 是否有迹象表明本次响应与本地记录属于不同版本。
    /// 缺少可对比的字段时按「未变化」处理，交由 If-Range 的语义保证。
    func matches(_ other: ResumeValidator) -> Bool {
        if let etag, let otherEtag = other.etag {
            return etag == otherEtag
        }
        if let lastModified, let otherModified = other.lastModified {
            return lastModified == otherModified
        }
        return true
    }
}

/// 把 validator 持久化到目标文件旁的隐藏 sidecar。
///
/// 只按目标路径存放还不够：同名目标可能先后下载不同 URL，因此记录
/// 请求 URL，仅当两者一致时才允许续传。
enum ResumeValidatorStore {
    private struct Record: Codable {
        let url: String
        let etag: String?
        let lastModified: String?
    }

    static func sidecarURL(for destination: URL) -> URL {
        destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).lumi-resume.json")
    }

    static func load(for destination: URL, url: URL) -> ResumeValidator? {
        guard let data = try? Data(contentsOf: sidecarURL(for: destination)),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.url == url.absoluteString else {
            return nil
        }
        return ResumeValidator(etag: record.etag, lastModified: record.lastModified)
    }

    static func save(_ validator: ResumeValidator, for destination: URL, url: URL) {
        let record = Record(url: url.absoluteString, etag: validator.etag, lastModified: validator.lastModified)
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: sidecarURL(for: destination), options: .atomic)
    }

    static func remove(for destination: URL) {
        try? FileManager.default.removeItem(at: sidecarURL(for: destination))
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
