import Foundation
import SwiftData

/// 专用于 LLM 请求日志的 SwiftData 存储
final class LLMRequestLogStore: @unchecked Sendable, LLMRequestLogging {
    static let shared = LLMRequestLogStore()

    private let container: ModelContainer
    private let queue = DispatchQueue(label: "LLMRequestLogStore.queue", qos: .utility)

    private init() {
        let schema = Schema([
            LLMRequestLog.self
        ])

        let dbDir = AppConfig.getDBFolderURL().appendingPathComponent("LLMRequestLoggerPlugin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("LLMRequestLog.sqlite")

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create LLMRequestLog ModelContainer: \(error)")
        }
    }

    /// 写入一条 LLM 请求日志（在后台队列中执行，不抛出错误）
    func log(
        providerId: String,
        model: String,
        url: URL,
        method: String,
        statusCode: Int?,
        durationMs: Double?,
        requestBody: Data?,
        responseBody: Data?,
        error: Error?
    ) {
        queue.async { [container] in
            let context = ModelContext(container)

            let maxBytes = 4 * 1024
            let requestPreview = requestBody.flatMap { data in
                data.count > maxBytes ? data.prefix(maxBytes) : data
            }
            let responsePreview = responseBody.flatMap { data in
                data.count > maxBytes ? data.prefix(maxBytes) : data
            }

            let errorDescription: String?
            if let error {
                errorDescription = (error as NSError).localizedDescription
            } else {
                errorDescription = nil
            }

            let log = LLMRequestLog(
                providerId: providerId,
                model: model,
                method: method,
                url: url.absoluteString,
                statusCode: statusCode,
                durationMs: durationMs,
                requestBodyPreview: requestPreview.map { Data($0) },
                responseBodyPreview: responsePreview.map { Data($0) },
                errorDescription: errorDescription
            )

            context.insert(log)
            try? context.save()
        }
    }
}
