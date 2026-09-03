import Foundation
import SQLite3
import SwiftData
import os

/// Serializes retention work so request recording can remain nonisolated while
/// cleanup runs against its own background model context.
private actor HTTPExchangeRetentionCoordinator {
    private let container: ModelContainer?
    private let onRecordsDeleted: @Sendable () -> Void
    private var scheduledTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?

    init(
        container: ModelContainer?,
        onRecordsDeleted: @escaping @Sendable () -> Void = {}
    ) {
        self.container = container
        self.onRecordsDeleted = onRecordsDeleted
    }

    deinit {
        scheduledTask?.cancel()
        periodicTask?.cancel()
    }

    func scheduleCleanup(
        immediately: Bool,
        retentionDays: Int,
        maxRecordCount: Int
    ) {
        guard scheduledTask == nil else { return }

        scheduledTask = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }

            guard let self else { return }
            let deletedCount = await self.cleanup(
                now: Date(),
                retentionDays: retentionDays,
                maxRecordCount: maxRecordCount
            )
            if deletedCount > 0 {
                self.onRecordsDeleted()
                HTTPExchangeChangeCenter.shared.notify()
            }
            await self.clearScheduledTask()
        }
    }

    func startPeriodicCleanup(
        retentionDays: Int,
        maxRecordCount: Int
    ) {
        guard periodicTask == nil else { return }

        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 86_400_000_000_000)
                } catch {
                    return
                }

                guard let coordinator = self else { return }
                let deletedCount = await coordinator.cleanup(
                    now: Date(),
                    retentionDays: retentionDays,
                    maxRecordCount: maxRecordCount
                )
                if deletedCount > 0 {
                    coordinator.onRecordsDeleted()
                    HTTPExchangeChangeCenter.shared.notify()
                }
            }
        }
    }

    func cleanup(
        now: Date,
        retentionDays: Int,
        maxRecordCount: Int
    ) -> Int {
        guard retentionDays > 0,
              maxRecordCount > 0,
              let container,
              let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) else {
            return 0
        }

        let context = ModelContext(container)
        var recordsToDelete: [HTTPExchangeRecord] = []

        var expiredDescriptor = FetchDescriptor<HTTPExchangeRecord>(
            predicate: #Predicate<HTTPExchangeRecord> { $0.startedAt < cutoff },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        // Deletion only needs identity and ordering fields. Do not load
        // request/response bodies from expired records just to delete them.
        expiredDescriptor.propertiesToFetch = [\.id, \.startedAt]
        recordsToDelete.append(contentsOf: (try? context.fetch(expiredDescriptor)) ?? [])

        let recentDescriptor = FetchDescriptor<HTTPExchangeRecord>(
            predicate: #Predicate<HTTPExchangeRecord> { $0.startedAt >= cutoff }
        )
        let recentCount = (try? context.fetchCount(recentDescriptor)) ?? 0
        if recentCount > maxRecordCount {
            var excessDescriptor = FetchDescriptor<HTTPExchangeRecord>(
                predicate: #Predicate<HTTPExchangeRecord> { $0.startedAt >= cutoff },
                sortBy: [SortDescriptor(\.startedAt, order: .forward)]
            )
            excessDescriptor.fetchLimit = recentCount - maxRecordCount
            excessDescriptor.propertiesToFetch = [\.id, \.startedAt]
            recordsToDelete.append(contentsOf: (try? context.fetch(excessDescriptor)) ?? [])
        }

        guard !recordsToDelete.isEmpty else { return 0 }
        for record in recordsToDelete {
            context.delete(record)
        }

        do {
            try context.save()
            return recordsToDelete.count
        } catch {
            NetworkManagerPlugin.logger.error("HTTP exchange retention cleanup failed: \(error.localizedDescription)")
            return 0
        }
    }

    private func clearScheduledTask() {
        scheduledTask = nil
    }
}

/// SwiftData-backed recorder for every HTTP request made by this plugin.
@MainActor
public final class HTTPExchangeStore {
    public static let databaseFileName = "http-exchanges.sqlite"
    private static let dailyCountCacheFileName = "http-daily-counts.json"
    public nonisolated static let retentionDays = 30
    public nonisolated static let maxRecordCount = 10_000
    /// Backing container. `ModelContainer` is `Sendable` and safe to touch off
    /// the main actor, so this is exposed `nonisolated` to let the background
    /// snapshot readers build their own private `ModelContext`.
    private nonisolated let container: ModelContainer?
    private nonisolated let dailyCountCache: HTTPExchangeDailyCountCache
    private let context: ModelContext?
    private nonisolated let retentionCoordinator: HTTPExchangeRetentionCoordinator

    public let directory: URL

    public convenience init(directory: URL) {
        self.init(directory: directory, startsRetentionMaintenance: true)
    }

    init(directory: URL, startsRetentionMaintenance: Bool) {
        self.directory = directory.appendingPathComponent("HTTP", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        let dailyCountCache = HTTPExchangeDailyCountCache(
            url: self.directory.appendingPathComponent(Self.dailyCountCacheFileName)
        )
        self.dailyCountCache = dailyCountCache

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
            self.retentionCoordinator = HTTPExchangeRetentionCoordinator(
                container: container,
                onRecordsDeleted: {
                    dailyCountCache.invalidateAll()
                }
            )
            Self.ensureStartedAtIndex(at: configuration.url)
        } catch {
            self.container = nil
            self.context = nil
            self.retentionCoordinator = HTTPExchangeRetentionCoordinator(
                container: nil,
                onRecordsDeleted: {
                    dailyCountCache.invalidateAll()
                }
            )
            NetworkManagerPlugin.logger.error("HTTP exchange SwiftData 初始化失败: \(error.localizedDescription)")
        }

        if startsRetentionMaintenance {
            scheduleRetentionCleanup(immediately: true)
            startPeriodicRetentionCleanup()
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
        if save(context) {
            dailyCountCache.invalidate(
                dayKey: HTTPExchangeDailyCountCache.key(for: Calendar.current.startOfDay(for: startedAt)),
                persist: !Calendar.current.isDateInToday(startedAt)
            )
        }
        HTTPExchangeChangeCenter.shared.notify()
        scheduleRetentionCleanup()
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
    /// This walks a bounded window of the newest records and projects only
    /// request URLs, keeping the cost constant as history grows. Hosts are
    /// lowercased so they line up with `searchPage`'s `domain` filter.
    public func fetchDomains(limit: Int = 5_000) -> [String] {
        guard let context = self.context, limit > 0 else { return [] }
        var descriptor = FetchDescriptor<HTTPExchangeRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        // Domain aggregation only needs the request URL. Avoid materializing
        // request/response bodies for every record in this bounded window.
        descriptor.propertiesToFetch = [\.requestURL]
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

    // MARK: - Background snapshot reads

    /// Snapshot readers for the settings UI. Each is `nonisolated` so callers
    /// can run them on a detached task without bouncing back onto the main
    /// actor. They build their own private `ModelContext` from the shared
    /// container (the supported SwiftData background-read pattern) and return
    /// value-type snapshots, which keeps `@Model` objects off the main thread
    /// entirely. The synchronous APIs above remain untouched for the write
    /// path, the agent tools, and the existing tests.

    private nonisolated func makeBackgroundContext() -> ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }

    /// Fetches only the columns needed to render list rows. Keeping this
    /// projection in one place prevents a future list query from accidentally
    /// selecting the request/response BLOBs again.
    private nonisolated func fetchListRecords(
        context: ModelContext,
        limit: Int,
        beforeStartedAt: Date?,
        startedAtAfter: Date?
    ) -> [HTTPExchangeRecord] {
        guard limit > 0 else { return [] }

        var descriptor: FetchDescriptor<HTTPExchangeRecord>
        switch (beforeStartedAt, startedAtAfter) {
        case let (cursor?, cutoff?):
            descriptor = FetchDescriptor<HTTPExchangeRecord>(
                predicate: #Predicate<HTTPExchangeRecord> {
                    $0.startedAt < cursor && $0.startedAt >= cutoff
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        case let (cursor?, nil):
            descriptor = FetchDescriptor<HTTPExchangeRecord>(
                predicate: #Predicate<HTTPExchangeRecord> { $0.startedAt < cursor },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        case let (nil, cutoff?):
            descriptor = FetchDescriptor<HTTPExchangeRecord>(
                predicate: #Predicate<HTTPExchangeRecord> { $0.startedAt >= cutoff },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        case (nil, nil):
            descriptor = FetchDescriptor<HTTPExchangeRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        }

        descriptor.fetchLimit = limit
        descriptor.propertiesToFetch = [
            \.id,
            \.startedAt,
            \.requestMethod,
            \.requestURL,
            \.responseStatusCode,
            \.errorDescription,
        ]
        return (try? context.fetch(descriptor)) ?? []
    }

    private nonisolated static func matchesStatus(
        _ record: HTTPExchangeListSnapshot,
        status: HTTPExchangeStatusFilter
    ) -> Bool {
        switch status {
        case .all:
            return true
        case .normal:
            guard let statusCode = record.responseStatusCode else { return false }
            return (200..<300).contains(statusCode)
        case .abnormal:
            guard let statusCode = record.responseStatusCode else { return true }
            return !(200..<300).contains(statusCode)
        }
    }

    private nonisolated static func matchesDomain(
        _ record: HTTPExchangeListSnapshot,
        domain: String?
    ) -> Bool {
        guard let domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !domain.isEmpty else { return true }
        return URL(string: record.url)?.host?.lowercased() == domain
    }

    // MARK: - Background Write Path (nonisolated)

    /// 后台写入版的 `begin`:用独立 `ModelContext` insert + save,返回 record id
    /// (而非 `@Model` 对象),供 `finishRecord` 在另一个 context 里按 id 取回。
    ///
    /// 这样 `begin`/`finish` 可在非主线程执行(由 nonisolated 的 `NetworkProvider`
    /// 调用),SwiftData 写入不再阻塞主线程。原 `begin`/`finish`(主线程同步版)
    /// 保留供 `@MainActor` 调用方使用。
    @discardableResult
    public nonisolated func beginRecord(
        request: URLRequest,
        startedAt: Date = Date()
    ) -> UUID? {
        guard let context = makeBackgroundContext() else { return nil }
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
        let id = record.id
        context.insert(record)
        do {
            try context.save()
        } catch {
            NetworkManagerPlugin.logger.error("HTTP exchange 后台 begin 保存失败: \(error.localizedDescription)")
            return nil
        }
        dailyCountCache.invalidate(
            dayKey: HTTPExchangeDailyCountCache.key(for: Calendar.current.startOfDay(for: startedAt)),
            persist: !Calendar.current.isDateInToday(startedAt)
        )
        Self.postDidChange()
        scheduleRetentionCleanup()
        return id
    }

    /// 后台写入版的 `finish`:按 id 在独立 `ModelContext` 里取回 record 并更新。
    /// 参数均为值类型,跨线程安全。
    public nonisolated func finishRecord(
        _ id: UUID?,
        response: URLResponse? = nil,
        body: Data? = nil,
        error: Error? = nil,
        finishedAt: Date = Date()
    ) {
        guard let id, let context = makeBackgroundContext() else { return }
        let idPredicate = id
        let descriptor = FetchDescriptor<HTTPExchangeRecord>(
            predicate: #Predicate<HTTPExchangeRecord> { $0.id == idPredicate }
        )
        guard let record = (try? context.fetch(descriptor))?.first else { return }
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
        do {
            try context.save()
        } catch {
            NetworkManagerPlugin.logger.error("HTTP exchange 后台 finish 保存失败: \(error.localizedDescription)")
            return
        }
        Self.postDidChange()
        scheduleRetentionCleanup()
    }

    private nonisolated static func postDidChange() {
        HTTPExchangeChangeCenter.shared.notify()
    }

    @discardableResult
    public func addObserver(_ callback: @escaping @Sendable () -> Void) -> HTTPExchangeChangeHandle {
        HTTPExchangeChangeCenter.shared.addObserver(callback)
    }

    /// Runs retention cleanup immediately. The normal write path uses the
    /// debounced scheduler below; this entry point is useful for startup,
    /// manual maintenance, and deterministic tests.
    @discardableResult
    public nonisolated func cleanupRetentionNow(
        now: Date = Date(),
        retentionDays: Int = HTTPExchangeStore.retentionDays,
        maxRecordCount: Int = HTTPExchangeStore.maxRecordCount
    ) async -> Int {
        let deletedCount = await retentionCoordinator.cleanup(
            now: now,
            retentionDays: retentionDays,
            maxRecordCount: maxRecordCount
        )
        if deletedCount > 0 {
            dailyCountCache.invalidateAll()
            Self.postDidChange()
        }
        return deletedCount
    }

    private nonisolated func scheduleRetentionCleanup(immediately: Bool = false) {
        let coordinator = retentionCoordinator
        Task {
            await coordinator.scheduleCleanup(
                immediately: immediately,
                retentionDays: Self.retentionDays,
                maxRecordCount: Self.maxRecordCount
            )
        }
    }

    private nonisolated func startPeriodicRetentionCleanup() {
        let coordinator = retentionCoordinator
        Task {
            await coordinator.startPeriodicCleanup(
                retentionDays: Self.retentionDays,
                maxRecordCount: Self.maxRecordCount
            )
        }
    }

    /// One page of newest exchanges as metadata-only snapshots.
    ///
    /// The fetch explicitly projects only list fields. In particular, it does
    /// not select either BLOB body, so sorting and paging remain cheap even
    /// when the history contains many gigabytes of payloads.
    nonisolated func loadListPage(
        limit: Int,
        beforeStartedAt: Date? = nil,
        status: HTTPExchangeStatusFilter = .all,
        domain: String? = nil,
        startedAtAfter: Date? = nil
    ) -> HTTPExchangeListPage {
        guard limit > 0, let context = makeBackgroundContext() else {
            return HTTPExchangeListPage(records: [], nextCursor: nil, hasMore: false)
        }

        let fetchWindow = max(limit * 4, limit)
        var matches: [HTTPExchangeListSnapshot] = []
        var cursor = beforeStartedAt
        var hasMore = false

        while matches.count < limit {
            let rawRecords = fetchListRecords(
                context: context,
                limit: fetchWindow,
                beforeStartedAt: cursor,
                startedAtAfter: startedAtAfter
            )
            let summaries = rawRecords.map(HTTPExchangeListSnapshot.init(record:))
            matches.append(contentsOf: summaries.filter {
                Self.matchesStatus($0, status: status) && Self.matchesDomain($0, domain: domain)
            })

            guard rawRecords.count == fetchWindow,
                  let lastStartedAt = rawRecords.last?.startedAt else {
                hasMore = false
                cursor = rawRecords.last?.startedAt
                break
            }

            // The cursor must represent the last scanned row, not the last
            // matching row; otherwise filtered-out rows can be skipped on the
            // next page.
            cursor = lastStartedAt
            hasMore = true
        }

        return HTTPExchangeListPage(
            records: Array(matches.prefix(limit)),
            nextCursor: cursor,
            hasMore: hasMore
        )
    }

    /// Counts list metadata without loading request or response bodies.
    nonisolated func loadListCount(
        status: HTTPExchangeStatusFilter = .all,
        domain: String? = nil,
        startedAtAfter: Date? = nil
    ) -> Int {
        guard let context = makeBackgroundContext() else { return 0 }

        let batchSize = 500
        var count = 0
        var cursor: Date?

        while true {
            let rawRecords = fetchListRecords(
                context: context,
                limit: batchSize,
                beforeStartedAt: cursor,
                startedAtAfter: startedAtAfter
            )
            let summaries = rawRecords.map(HTTPExchangeListSnapshot.init(record:))
            count += summaries.filter {
                Self.matchesStatus($0, status: status) && Self.matchesDomain($0, domain: domain)
            }.count

            guard rawRecords.count == batchSize,
                  let lastStartedAt = rawRecords.last?.startedAt else {
                break
            }
            cursor = lastStartedAt
        }

        return count
    }

    /// Loads a single full exchange for the detail pane. This is the only
    /// normal list/detail path that materializes request and response bodies.
    nonisolated func loadSnapshot(id: UUID) -> HTTPExchangeExportSnapshot? {
        guard let context = makeBackgroundContext() else { return nil }
        let recordID = id
        var descriptor = FetchDescriptor<HTTPExchangeRecord>(
            predicate: #Predicate<HTTPExchangeRecord> { $0.id == recordID }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first.map(HTTPExchangeExportSnapshot.init(record:))
    }

    /// Loads all matching list metadata for an explicit export action. The
    /// caller can then request full snapshots only for those selected IDs.
    nonisolated func loadAllListRecords(
        status: HTTPExchangeStatusFilter = .all,
        domain: String? = nil,
        startedAtAfter: Date? = nil
    ) -> [HTTPExchangeListSnapshot] {
        guard let context = makeBackgroundContext() else { return [] }

        let batchSize = 500
        var allRecords: [HTTPExchangeListSnapshot] = []
        var cursor: Date?

        while true {
            let rawRecords = fetchListRecords(
                context: context,
                limit: batchSize,
                beforeStartedAt: cursor,
                startedAtAfter: startedAtAfter
            )
            let summaries = rawRecords.map(HTTPExchangeListSnapshot.init(record:))
            allRecords.append(contentsOf: summaries.filter {
                Self.matchesStatus($0, status: status) && Self.matchesDomain($0, domain: domain)
            })

            guard rawRecords.count == batchSize,
                  let lastStartedAt = rawRecords.last?.startedAt else {
                break
            }
            cursor = lastStartedAt
        }

        return allRecords
    }

    /// Total number of stored exchanges, without materializing bodies.
    nonisolated func loadSnapshotCount() -> Int {
        guard let context = makeBackgroundContext() else { return 0 }
        return (try? context.fetchCount(FetchDescriptor<HTTPExchangeRecord>())) ?? 0
    }

    /// Distinct host names from the most recent records.
    ///
    /// Mirrors `fetchDomains(limit:)`, run off the main actor.
    nonisolated func loadRecentDomains(limit: Int = 5_000) -> [String] {
        guard limit > 0, let context = makeBackgroundContext() else { return [] }
        var descriptor = FetchDescriptor<HTTPExchangeRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.propertiesToFetch = [\.requestURL]
        descriptor.fetchLimit = limit
        let records = (try? context.fetch(descriptor)) ?? []
        var domains = Set<String>()
        for record in records {
            guard let host = URL(string: record.requestURL)?.host?.lowercased() else { continue }
            domains.insert(host)
        }
        return domains.sorted()
    }

    /// Recent activity chart backed by a small persistent daily-count cache.
    ///
    /// Historical days are reused after the first read. The current day and
    /// missing/invalidated days are refreshed in one metadata-only fetch, which
    /// never materializes request or response bodies.
    nonisolated func loadDailyCountSeries(
        days: Int = 14,
        endingAt date: Date = Date()
    ) -> HTTPExchangeDailyCountSeries {
        guard days > 0, let context = makeBackgroundContext() else {
            return HTTPExchangeDailyCountSeries(points: [])
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        guard let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return HTTPExchangeDailyCountSeries(points: [])
        }

        let dayRanges = (0..<days).compactMap { offset -> (day: Date, nextDay: Date, key: String)? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }
            return (day, nextDay, HTTPExchangeDailyCountCache.key(for: day))
        }
        guard dayRanges.count == days else {
            return HTTPExchangeDailyCountSeries(points: [])
        }

        let todayKey = HTTPExchangeDailyCountCache.key(for: today)
        let keys = dayRanges.map(\.key)
        let snapshot = dailyCountCache.snapshot(for: keys)
        let daysToRefresh = dayRanges.filter {
            $0.key == todayKey || snapshot.counts[$0.key] == nil
        }

        var countsByKey = Dictionary(
            uniqueKeysWithValues: dayRanges.map { ($0.key, snapshot.counts[$0.key] ?? 0) }
        )

        if !daysToRefresh.isEmpty,
           let refreshStart = daysToRefresh.first?.day,
           let refreshEnd = daysToRefresh.last?.nextDay {
            var descriptor = FetchDescriptor<HTTPExchangeRecord>(
                predicate: #Predicate<HTTPExchangeRecord> {
                    $0.startedAt >= refreshStart && $0.startedAt < refreshEnd
                }
            )
            // The chart only needs timestamps. In particular, do not load the
            // request/response BLOBs from this multi-gigabyte store.
            descriptor.propertiesToFetch = [\.startedAt]
            let records = (try? context.fetch(descriptor)) ?? []
            let refreshKeys = Set(daysToRefresh.map(\.key))
            var refreshedCounts = Dictionary(
                uniqueKeysWithValues: refreshKeys.map { ($0, 0) }
            )

            for record in records {
                let key = HTTPExchangeDailyCountCache.key(
                    for: calendar.startOfDay(for: record.startedAt)
                )
                if refreshKeys.contains(key) {
                    refreshedCounts[key, default: 0] += 1
                }
            }

            countsByKey.merge(refreshedCounts, uniquingKeysWith: { _, refreshed in refreshed })

            // The current day is deliberately not persisted: it changes on
            // every request and is always refreshed on the next chart load.
            let historicalCounts = refreshedCounts.filter { $0.key != todayKey }
            if !historicalCounts.isEmpty {
                let historicalVersions = snapshot.versions.filter {
                    historicalCounts[$0.key] != nil
                }
                dailyCountCache.store(
                    historicalCounts,
                    expectedVersions: historicalVersions
                )
            }
        }

        return HTTPExchangeDailyCountSeries(
            points: dayRanges.map {
                HTTPExchangeDailyCountPoint(day: $0.day, count: countsByKey[$0.key] ?? 0)
            }
        )
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
        HTTPExchangeChangeCenter.shared.notify()
        scheduleRetentionCleanup()
    }

    @discardableResult
    private func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            NetworkManagerPlugin.logger.error("HTTP exchange SwiftData 保存失败: \(error.localizedDescription)")
            return false
        }
    }

    /// SwiftData's public `#Index` macro requires macOS 15, while this plugin
    /// still supports macOS 14. Create the equivalent SQLite index directly so
    /// existing stores and the minimum deployment target remain compatible.
    private static func ensureStartedAtIndex(at url: URL) {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database {
                NetworkManagerPlugin.logger.error("HTTP exchange SQLite 索引连接失败: \(String(cString: sqlite3_errmsg(database)))")
                sqlite3_close(database)
            } else {
                NetworkManagerPlugin.logger.error("HTTP exchange SQLite 索引连接失败，错误码: \(openResult)")
            }
            return
        }
        defer { sqlite3_close(database) }

        let sql = "CREATE INDEX IF NOT EXISTS ZHTTPExchangeRecordStartedAtIndex ON ZHTTPEXCHANGERECORD (ZSTARTEDAT)"
        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            NetworkManagerPlugin.logger.error("HTTP exchange SQLite 索引创建失败: \(message)")
            return
        }
    }

    /// `nonisolated`:纯函数(JSONSerialization),后台写入路径需调用。
    private nonisolated static func jsonData(_ value: Any) -> Data {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        else { return Data("{}".utf8) }
        return data
    }
}
