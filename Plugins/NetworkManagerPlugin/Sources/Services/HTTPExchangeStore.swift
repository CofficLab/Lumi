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

    /// Fetch one page using a keyset cursor ordered by newest first.
    ///
    /// The bounded fetch keeps the settings UI from materializing the entire
    /// HTTP history, even when the database grows without a fixed limit.
    public func fetchPage(
        limit: Int,
        beforeStartedAt: Date? = nil
    ) -> [HTTPExchangeRecord] {
        guard let context = self.context, limit > 0 else { return [] }

        let cursorDate = beforeStartedAt
        var descriptor: FetchDescriptor<HTTPExchangeRecord>

        if let cursorDate {
            descriptor = FetchDescriptor<HTTPExchangeRecord>(
                predicate: #Predicate<HTTPExchangeRecord> {
                    $0.startedAt < cursorDate
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<HTTPExchangeRecord>(sortBy: [
                SortDescriptor(\.startedAt, order: .reverse),
            ])
        }

        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Count stored exchanges without materializing request or response bodies.
    public func count() -> Int {
        guard let context = self.context else { return 0 }
        return (try? context.fetchCount(FetchDescriptor<HTTPExchangeRecord>())) ?? 0
    }

    /// Build the recent activity chart with bounded count queries per day.
    func fetchDailyCountSeries(days: Int = 14, endingAt date: Date = Date()) -> HTTPExchangeDailyCountSeries {
        guard days > 0, let context = self.context else {
            return HTTPExchangeDailyCountSeries(points: [])
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let points = (0..<days).compactMap { offset -> HTTPExchangeDailyCountPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }

            let descriptor = FetchDescriptor<HTTPExchangeRecord>(
                predicate: #Predicate<HTTPExchangeRecord> {
                    $0.startedAt >= day && $0.startedAt < nextDay
                }
            )
            let count = (try? context.fetchCount(descriptor)) ?? 0
            return HTTPExchangeDailyCountPoint(day: day, count: count)
        }
        return HTTPExchangeDailyCountSeries(points: points)
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
