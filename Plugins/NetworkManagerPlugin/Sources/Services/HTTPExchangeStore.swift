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

    /// Collect distinct host names from recent records.
    ///
    /// SwiftData offers no single-column projection, so this walks a bounded
    /// window of the newest records instead of the full table, keeping the
    /// cost constant as history grows. Hosts are lowercased so they line up
    /// with `searchPage`'s `domain` filter.
    public func fetchDomains(limit: Int = 5_000) -> [String] {
        guard let context = self.context, limit > 0 else { return [] }
        var descriptor = FetchDescriptor<HTTPExchangeRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let records = (try? context.fetch(descriptor)) ?? []
        var domains = Set<String>()
        for record in records {
            guard let host = URL(string: record.requestURL)?.host?.lowercased() else { continue }
            domains.insert(host)
        }
        return domains.sorted()
    }

    /// Search HTTP exchanges with optional filters.
    ///
    /// The keyset cursor (`beforeStartedAt`) is applied via SwiftData predicate
    /// to keep the page boundary stable, while the remaining filters
    /// (URL keyword, method, status code) are evaluated in Swift. This avoids
    /// the `#Predicate` macro's restrictions on combining optional conditions
    /// and keeps the call site simple. The window is sized generously so that
    /// after in-memory filtering we still have a full page.
    public func searchPage(
        limit: Int,
        beforeStartedAt: Date? = nil,
        urlContains: String? = nil,
        method: String? = nil,
        statusCode: Int? = nil,
        domain: String? = nil
    ) -> [HTTPExchangeRecord] {
        guard let context = self.context, limit > 0 else { return [] }

        // A coarse over-fetch window lets the in-memory filter still produce
        // up to `limit` results even when only a fraction of the database
        // matches. 4× is a pragmatic balance between fetch cost and pagination
        // granularity.
        let windowSize = max(limit * 4, limit)
        let normalizedURL = urlContains?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMethod = method?.uppercased()
        let normalizedDomain = domain?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let cursor = beforeStartedAt
        let rawRecords: [HTTPExchangeRecord]
        if let cursor {
            let descriptor = FetchDescriptor<HTTPExchangeRecord>(
                predicate: #Predicate<HTTPExchangeRecord> { $0.startedAt < cursor },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            var bounded = descriptor
            bounded.fetchLimit = windowSize
            rawRecords = (try? context.fetch(bounded)) ?? []
        } else {
            var descriptor = FetchDescriptor<HTTPExchangeRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            descriptor.fetchLimit = windowSize
            rawRecords = (try? context.fetch(descriptor)) ?? []
        }

        let filtered = rawRecords.filter { record in
            if let normalizedDomain, !normalizedDomain.isEmpty {
                guard let host = URL(string: record.requestURL)?.host?.lowercased(),
                      host == normalizedDomain else { return false }
            }
            if let normalizedURL, !normalizedURL.isEmpty {
                if !record.requestURL.localizedCaseInsensitiveContains(normalizedURL),
                   !(record.errorDescription?.localizedCaseInsensitiveContains(normalizedURL) ?? false) {
                    return false
                }
            }
            if let normalizedMethod {
                if record.requestMethod.uppercased() != normalizedMethod { return false }
            }
            if let statusCode {
                if record.responseStatusCode != statusCode { return false }
            }
            return true
        }

        return Array(filtered.prefix(limit))
    }

    /// Count HTTP exchanges matching the same filters as `searchPage`.
    ///
    /// Uses `fetchCount` with the same keyset cursor to avoid materializing
    /// bodies, then filters in Swift. Result is only an approximation when
    /// filters are active and the underlying table is large.
    public func searchCount(
        urlContains: String? = nil,
        method: String? = nil,
        statusCode: Int? = nil,
        domain: String? = nil
    ) -> Int {
        guard let context = self.context else { return 0 }

        let normalizedURL = urlContains?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMethod = method?.uppercased()
        let normalizedDomain = domain?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isFiltered = (normalizedURL?.isEmpty == false)
            || normalizedMethod != nil
            || statusCode != nil
            || (normalizedDomain?.isEmpty == false)

        if !isFiltered {
            return (try? context.fetchCount(FetchDescriptor<HTTPExchangeRecord>())) ?? 0
        }

        // Fetch IDs only to keep this cheap; fall back to full scan for filtered counts.
        var descriptor = FetchDescriptor<HTTPExchangeRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        // Cap to a reasonable upper bound so an unfiltered count query
        // doesn't scan unbounded history just to render a label.
        descriptor.fetchLimit = 5_000
        let records = (try? context.fetch(descriptor)) ?? []
        return records.filter { record in
            if let normalizedDomain, !normalizedDomain.isEmpty {
                guard let host = URL(string: record.requestURL)?.host?.lowercased(),
                      host == normalizedDomain else { return false }
            }
            if let normalizedURL, !normalizedURL.isEmpty {
                if !record.requestURL.localizedCaseInsensitiveContains(normalizedURL),
                   !(record.errorDescription?.localizedCaseInsensitiveContains(normalizedURL) ?? false) {
                    return false
                }
            }
            if let normalizedMethod, record.requestMethod.uppercased() != normalizedMethod {
                return false
            }
            if let statusCode, record.responseStatusCode != statusCode {
                return false
            }
            return true
        }.count
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
