import Foundation
import SwiftData
import os

/// SwiftData-backed recorder for every HTTP request made by this plugin.
@MainActor
public final class HTTPExchangeStore {
    public static let databaseFileName = "http-exchanges.sqlite"
    public static let didChangeNotification = Notification.Name("com.coffic.lumi.networkManagerHTTPExchangeDidChange")

    private let container: ModelContainer?
    private let context: ModelContext?

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory.appendingPathComponent("HTTP", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)

        do {
            let schema = Schema([HTTPExchangeRecord.self])
            let configuration = ModelConfiguration(
                "NetworkManagerHTTP",
                schema: schema,
                url: self.directory.appendingPathComponent(Self.databaseFileName)
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.container = container
            self.context = ModelContext(container)
        } catch {
            self.container = nil
            self.context = nil
            NetworkManagerPlugin.logger.error("HTTP exchange SwiftData 初始化失败: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func begin(request: URLRequest, startedAt: Date = Date()) -> HTTPExchangeRecord? {
        guard let context = self.context else { return nil }
        let record = HTTPExchangeRecord(
            startedAt: startedAt,
            requestMethod: request.httpMethod ?? "GET",
            requestURL: request.url?.absoluteString ?? "",
            requestHeadersJSON: Self.jsonData(request.allHTTPHeaderFields ?? [:]),
            requestBody: request.httpBody,
            requestDetailsJSON: Self.jsonData([
                "cachePolicy": request.cachePolicy.rawValue,
                "timeoutInterval": request.timeoutInterval,
                "httpShouldHandleCookies": request.httpShouldHandleCookies,
                "httpShouldUsePipelining": request.httpShouldUsePipelining,
                "allowsCellularAccess": request.allowsCellularAccess,
                "networkServiceType": request.networkServiceType.rawValue,
                "mainDocumentURL": request.mainDocumentURL?.absoluteString ?? NSNull(),
            ])
        )
        context.insert(record)
        save(context)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        return record
    }

    public func fetchAll() -> [HTTPExchangeRecord] {
        guard let context = self.context else { return [] }
        let descriptor = FetchDescriptor<HTTPExchangeRecord>(sortBy: [
            SortDescriptor(\.startedAt, order: .reverse),
        ])
        return (try? context.fetch(descriptor)) ?? []
    }

    public func finish(
        _ record: HTTPExchangeRecord?,
        response: URLResponse? = nil,
        body: Data? = nil,
        error: Error? = nil,
        finishedAt: Date = Date()
    ) {
        guard let record, let context = self.context else { return }
        record.finishedAt = finishedAt
        record.duration = finishedAt.timeIntervalSince(record.startedAt)
        record.responseBody = body

        if let response {
            record.responseURL = response.url?.absoluteString
            record.responseMIMEType = response.mimeType
            record.responseExpectedContentLength = response.expectedContentLength
            record.responseTextEncodingName = response.textEncodingName
        }
        if let httpResponse = response as? HTTPURLResponse {
            record.responseStatusCode = httpResponse.statusCode
            record.responseHeadersJSON = Self.jsonData(httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
                result[String(describing: item.key)] = String(describing: item.value)
            })
        }
        if let error {
            let nsError = error as NSError
            record.errorDomain = nsError.domain
            record.errorCode = nsError.code
            record.errorDescription = nsError.localizedDescription
            record.errorDetailsJSON = Self.jsonData(nsError.userInfo.reduce(into: [String: String]()) { result, item in
                result[String(describing: item.key)] = String(describing: item.value)
            })
        }
        save(context)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            NetworkManagerPlugin.logger.error("HTTP exchange SwiftData 保存失败: \(error.localizedDescription)")
        }
    }

    private static func jsonData(_ value: Any) -> Data {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        else { return Data("{}".utf8) }
        return data
    }
}
