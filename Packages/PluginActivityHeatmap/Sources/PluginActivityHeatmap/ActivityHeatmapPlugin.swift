import Foundation
import KernelCore
import LumiLocalizationKit
import LumiUI
import ProviderGit
import ProviderMessage
import ProviderActivityHeatmap
import ProviderGit
import ProviderGitRepositoryWatch
import ProviderSettingView
import ProviderIdleTime
import ProviderDocsView
import ProviderStorage
import SwiftUI
import LumiLoggingKit
import os

/// V2 activity dashboard. It preserves the legacy heatmap's three time ranges,
/// daily message intensity, token trend, and persisted range preference while
/// consuming only KernelCore providers.
@MainActor
public final class ActivityHeatmapPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.activity-heatmap", category: "ActivityHeatmap")
    public let id = "com.coffic.activity-heatmap"
    public let legacyDataDirectoryNames = ["ActivityHeatmap"]
    public let order = 9
    public let dependencies = [
        "com.coffic.lumi.plugin.projects",
        "com.coffic.lumi.plugin.git-repository-watch",
    ]
    public let metadata = PluginMetadata(
        id: "com.coffic.activity-heatmap",
        name: "Activity Heatmap",
        description: "Display daily conversation activity and token consumption.",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    private var cache: ActivityHeatmapCache?
    private var gitActivityProvider: LocalGitActivityHeatmapProvider?
    private var gitWatchHandle: (any GitRepositoryWatchingObserverHandle)?
    private var projectSectionObservers: [String: GitActivityHeatmapProjectObserver] = [:]
    private var viewModel: ActivityHeatmapViewModel?
    private var insertionObserver: MessageObserver?
    private var idleTimeState: ActivityHeatmapIdleTimeState?
    private var idleTimeObserver: ActivityHeatmapIdleTimeObserver?

    public init() {}

    /// 提交活动只随「当前分支提交历史」变化而重算：refs 变化或 HEAD 变化都要刷新。
    /// 切到已存在的分支只改 HEAD 符号引用、refs 不变，故 headChanged 也必须触发；
    /// index/stash/workingTree 不影响提交历史，不刷新以免无谓重算。
    nonisolated static func shouldRefreshCommitActivity(for event: GitRepositoryWatchingEvent) -> Bool {
        switch event {
        case .refsChanged, .headChanged:
            return true
        case .started, .stopped, .indexChanged, .stashChanged, .workingTreeChanged:
            return false
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let provider = LocalGitActivityHeatmapProvider(
                directory: storage.pluginDataDirectory(for: id),
                git: kernel.resolveProvider((any GitRepositoryReading).self)
            )
            gitActivityProvider = provider
            try kernel.registerProvider((any ActivityHeatmapProviding).self, provider)

            if let gitWatch = kernel.resolveProvider((any GitRepositoryWatching).self) {
                gitWatchHandle = gitWatch.addObserver { [weak provider, weak gitWatch] event in
                    guard Self.shouldRefreshCommitActivity(for: event),
                          let repository = gitWatch?.watchingRepositoryURL else { return }
                    provider?.refresh(for: repository)
                }
            }

            if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
                settings.addProjectDetailSections([
                    ProjectDetailSectionItem(
                        id: "\(id).project-activity",
                        order: 180
                    ) { path in
                        let capability = GitActivityHeatmapProjectCapability(provider: provider)
                        let viewModel = GitActivityHeatmapProjectViewModel(
                            projectPath: path,
                            capability: capability
                        )
                        let observer = GitActivityHeatmapProjectObserver(
                            capability: capability,
                            viewModel: viewModel
                        )
                        self.projectSectionObservers[path] = observer
                        return GitActivityHeatmapProjectSection(
                            projectPath: path,
                            viewModel: viewModel
                        )
                    }
                ])
            }
        } else {
            Self.logger.error("\(Self.t) StorageProviding not found; Git activity heatmap is unavailable")
        }

        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            Self.logger.error("\(Self.t) SettingViewProviding not found")
            return
        }
        let messages = kernel.resolveProvider((any MessageManaging).self)
        if messages == nil {
            Self.logger.error("\(Self.t) MessageManaging not found")
        }
        let idleTime = kernel.resolveProvider((any IdleTimeProviding).self)
        if idleTime == nil {
            Self.logger.error("\(Self.t) IdleTimeProviding not found")
        }
        let directory = kernel.resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: id)
        let settingsDirectory = directory?.appendingPathComponent("settings", isDirectory: true)
        let preferences = ActivityHeatmapPreferences(
            settingsDirectory: settingsDirectory ?? FileManager.default.temporaryDirectory
        )
        ActivityHeatmapViewModel.restoreLegacyPeriodIfNeeded(from: directory, preferences: preferences)
        cache = ActivityHeatmapCache(directory: directory)
        let viewModel = ActivityHeatmapViewModel(messages: messages, cache: cache, preferences: preferences)
        self.viewModel = viewModel
        if let messages {
            insertionObserver = MessageObserver(messages: messages) { [weak self] in
                Task { @MainActor in
                    self?.viewModel?.scheduleReload()
                }
            }
        }
        if let idleTime {
            let idleTimeState = ActivityHeatmapIdleTimeState(provider: idleTime)
            self.idleTimeState = idleTimeState
            idleTimeObserver = ActivityHeatmapIdleTimeObserver(provider: idleTime) { [weak idleTimeState] in
                Task { @MainActor in
                    idleTimeState?.refresh()
                }
            }
            idleTimeState.refresh()
        }
        settings.addEntries([
            SettingEntryItem(
                id: id,
                title: pluginLocalization.string("Activity Heatmap"),
                systemImage: "chart.bar.xaxis",
                order: order
            ) {
                ActivityHeatmapSettingsView(
                    model: viewModel,
                    idleTime: idleTime,
                    idleTimeState: self.idleTimeState
                )
            },
        ])
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(
                DocsEntry(id: id, name: pluginLocalization.string("Activity Heatmap")) { ActivityHeatmapAboutView() }
            )
            docs.addManual(
                DocsEntry(id: id, name: pluginLocalization.string("Activity Heatmap")) { ActivityHeatmapManualView() }
            )
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        gitWatchHandle?.cancel()
        gitWatchHandle = nil
        gitActivityProvider = nil
        kernel.unregisterProvider((any ActivityHeatmapProviding).self)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeProjectDetailSections(
            ids: ["\(id).project-activity"]
        )
        for observer in projectSectionObservers.values {
            observer.cancel()
        }
        projectSectionObservers.removeAll()
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
        insertionObserver?.cancel()
        insertionObserver = nil
        idleTimeObserver?.cancel()
        idleTimeObserver = nil
        idleTimeState = nil
        viewModel = nil
        cache = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

}

public enum ActivityHeatmapPeriod: Int, CaseIterable, Identifiable, Sendable {
    case days30 = 30
    case days90 = 90
    case year = 365

    public var id: Int { rawValue }
    var title: String {
        switch self {
        case .days30: pluginLocalization.string("Last 30 days")
        case .days90: pluginLocalization.string("Last 90 days")
        case .year: pluginLocalization.string("Last year")
        }
    }
}

public struct ActivityDay: Identifiable, Sendable, Equatable {
    public let date: Date
    public let messages: Int
    public let tokens: Int
    public var id: Date { date }
}

@MainActor
public final class ActivityHeatmapViewModel: ObservableObject {
    private let messages: (any MessageManaging)?
    private let cache: ActivityHeatmapCache?
    private let preferences: ActivityHeatmapPreferences
    /// 本地「现在」。测试注入固定值以模拟跨过本地午夜（#507）。
    let dayStartProvider: () -> Date
    private var reloadTask: Task<Void, Never>?
    private var reloadGeneration = 0
    static let periodKey = ActivityHeatmapPreferences.periodKey

    @Published public var period: ActivityHeatmapPeriod {
        didSet { preferences.setStoredPeriodRawValue(period.rawValue) }
    }
    @Published public private(set) var days: [ActivityDay] = []
    /// The heatmap keeps a full year's daily history so its layout can decide
    /// how much to show from the available space independently of `period`.
    @Published public private(set) var heatmapDays: [ActivityDay] = []
    @Published public private(set) var isLoading = false
    /// Days drawn by the token trend chart. Fixed to 30 days so the line chart
    /// matches the HTTP log and conversation dashboards, and so a restored
    /// legacy "last year" preference cannot pack 365 points into one width.
    public var trendDays: [ActivityDay] {
        Array(heatmapDays.suffix(ActivityHeatmapPeriod.days30.rawValue))
    }
    /// The day with the highest token consumption inside ``trendDays``, shown
    /// under the trend chart. Nil when no tokens were consumed in that window.
    public var peakTokenDay: ActivityDay? {
        trendDays.max { $0.tokens < $1.tokens }.flatMap { $0.tokens > 0 ? $0 : nil }
    }

    public init(
        messages: (any MessageManaging)?,
        cache: ActivityHeatmapCache? = nil,
        preferences: ActivityHeatmapPreferences,
        dayStartProvider: @escaping () -> Date = { Date() }
    ) {
        self.messages = messages
        self.cache = cache
        self.preferences = preferences
        self.dayStartProvider = dayStartProvider
        self.period = ActivityHeatmapPeriod(rawValue: preferences.storedPeriodRawValue ?? 0) ?? .days30
    }

    /// 本地「今天」的零点。
    private var currentDayStart: Date {
        Calendar.current.startOfDay(for: dayStartProvider())
    }

    /// 监控本地日界变化（#507）。
    ///
    /// 页面停留期间跨过本地午夜时，新的一天不会由消息插入触发重载，
    /// 窗口会停留在昨天。此监控周期性比较 `startOfDay`，一旦变化（跨午夜、
    /// 时区/日历变更、休眠唤醒后日期不同）立即重载窗口。取消随调用方任务
    /// 传播（设置页 `.task` 在视图消失时自动取消），无需额外停止入口。
    func runDayRolloverMonitor(pollInterval: Duration = .seconds(30)) async {
        var dayStart = currentDayStart
        while !Task.isCancelled {
            try? await Task.sleep(for: pollInterval)
            if Task.isCancelled { return }
            let current = currentDayStart
            guard current != dayStart else { continue }
            dayStart = current
            await reloadNow()
        }
    }

    /// 从旧版 JSON 设置（`settings/settings.json`）恢复周期偏好。
    ///
    /// 仅在插件存储与 UserDefaults 都尚无记录时写入，沿用原有「首启才恢复」语义。
    static func restoreLegacyPeriodIfNeeded(from directory: URL?, preferences: ActivityHeatmapPreferences) {
        let periodKey = Self.periodKey
        let hasStoredValue = preferences.storedPeriodRawValue != nil
        let hasLegacyUserDefaultsValue = UserDefaults.standard.object(forKey: periodKey) != nil
        guard !hasStoredValue, !hasLegacyUserDefaultsValue,
              let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("settings/settings.json")),
              let legacy = try? JSONDecoder().decode(LegacyPeriodPreference.self, from: data),
              let rawValue = legacy.selectedPeriodRawValue,
              ActivityHeatmapPeriod(rawValue: rawValue) != nil
        else { return }
        preferences.setStoredPeriodRawValue(rawValue)
    }

    public func reload() async {
        reloadTask?.cancel()
        reloadTask = nil
        await reloadNow()
    }

    /// Debounced entry point for change-driven refreshes (e.g. message insertion).
    ///
    /// A burst of insertions cancels and restarts a single retained task, so only
    /// the latest reload runs once the window settles. This avoids launching one
    /// overlapping reload pipeline per inserted message (see issue #1262).
    public func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task(priority: .utility) { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            self.reloadTask = nil
            await self.reloadNow()
        }
    }

    private func reloadNow() async {
        reloadGeneration += 1
        let generation = reloadGeneration
        guard let messages else {
            days = []
            heatmapDays = []
            return
        }
        isLoading = true
        defer {
            if generation == reloadGeneration {
                isLoading = false
            }
        }
        let calendar = Calendar.current
        let today = currentDayStart
        let heatmapDayCount = ActivityHeatmapPeriod.year.rawValue
        guard let start = calendar.date(byAdding: .day, value: -(heatmapDayCount - 1), to: today) else {
            isLoading = false
            return
        }
        let historicalDates = (0..<(heatmapDayCount - 1)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
        guard !Task.isCancelled, generation == reloadGeneration else { return }
        let cached = await cache?.counts(for: historicalDates) ?? [:]
        guard !Task.isCancelled, generation == reloadGeneration else { return }
        let missingDates = historicalDates.filter { cached[$0] == nil }
        let fetchedHistoricalMessages: [Date: Int]
        let fetchedHistoricalTokens: [Date: Int]
        if let firstMissingDate = missingDates.first {
            fetchedHistoricalMessages = await messages.dailyMessageCountsAsync(since: firstMissingDate)
            guard !Task.isCancelled, generation == reloadGeneration else { return }
            fetchedHistoricalTokens = await messages.dailyTokenCountsAsync(since: firstMissingDate)
            guard !Task.isCancelled, generation == reloadGeneration else { return }
        } else {
            fetchedHistoricalMessages = [:]
            fetchedHistoricalTokens = [:]
        }
        let historical = missingDates.reduce(into: [Date: ActivityHeatmapCache.Counts]()) { values, date in
            values[date] = .init(
                messages: fetchedHistoricalMessages[date, default: 0],
                tokens: fetchedHistoricalTokens[date, default: 0]
            )
        }
        await cache?.save(historical)
        guard !Task.isCancelled, generation == reloadGeneration else { return }
        let todayMessages = await messages.dailyMessageCountsAsync(since: today)
        guard !Task.isCancelled, generation == reloadGeneration else { return }
        let todayTokens = await messages.dailyTokenCountsAsync(since: today)
        guard !Task.isCancelled, generation == reloadGeneration else { return }
        let loadedDays: [ActivityDay] = (0..<heatmapDayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let isToday = date == today
            let cachedDay = cached[date]
            return ActivityDay(
                date: date,
                messages: isToday ? todayMessages[date, default: 0] : cachedDay?.messages ?? historical[date]?.messages ?? 0,
                tokens: isToday ? todayTokens[date, default: 0] : cachedDay?.tokens ?? historical[date]?.tokens ?? 0
            )
        }
        heatmapDays = loadedDays
        days = Array(loadedDays.suffix(period.rawValue))
    }
}

private struct LegacyPeriodPreference: Decodable {
    let selectedPeriodRawValue: Int?
}

public struct ActivityHeatmapSettingsView: View {
    @ObservedObject private var model: ActivityHeatmapViewModel
    @LumiTheme private var theme
    private let idleTime: (any IdleTimeProviding)?
    private let idleTimeState: ActivityHeatmapIdleTimeState

    private static let activityCellMinimumSize: CGFloat = 10
    private static let activityCellMaximumSize: CGFloat = 14
    private static let activityCellSpacing: CGFloat = 4
    private static let activityRowCount = 7
    private static let activityMaximumColumnCount = 53

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    public init(
        model: ActivityHeatmapViewModel,
        idleTime: (any IdleTimeProviding)? = nil,
        idleTimeState: ActivityHeatmapIdleTimeState? = nil
    ) {
        self.model = model
        self.idleTime = idleTime
        self.idleTimeState = idleTimeState ?? ActivityHeatmapIdleTimeState(provider: idleTime)
    }

    public init(
        messages: (any MessageManaging)?,
        idleTime: (any IdleTimeProviding)? = nil,
        cache: ActivityHeatmapCache? = nil,
        preferences: ActivityHeatmapPreferences
    ) {
        self.model = ActivityHeatmapViewModel(messages: messages, cache: cache, preferences: preferences)
        self.idleTime = idleTime
        self.idleTimeState = ActivityHeatmapIdleTimeState(provider: idleTime)
    }

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                summary
                heatmap
                tokenTrend
                if idleTime != nil {
                    IdleTimeSummaryCard(state: idleTimeState)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await model.reload()
            // 停留在页面上跨过本地午夜时自动滚动窗口（#507）；
            // 视图消失时 `.task` 取消，监控随之停止。
            await model.runDayRolloverMonitor()
        }
    }

    private var summary: some View {
        let totalMessages = model.heatmapDays.reduce(0) { $0 + $1.messages }
        let totalTokens = model.heatmapDays.reduce(0) { $0 + $1.tokens }
        let activeDays = model.heatmapDays.filter { $0.messages > 0 }.count
        return HStack(spacing: 12) {
            metric(L("Messages"), value: "\(totalMessages)", symbol: "bubble.left.and.bubble.right")
            metric(L("Active days"), value: "\(activeDays)", symbol: "calendar")
            metric(L("Tokens"), value: TokenCountFormat.compact(totalTokens), symbol: "number")
        }
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Daily activity")).font(.headline)
            GeometryReader { proxy in
                let layout = activityGridLayout(
                    for: proxy.size.width,
                    availableDayCount: model.heatmapDays.count
                )
                let visibleDays = columnMajorDays(
                    Array(model.heatmapDays.suffix(layout.visibleDayCount)),
                    columnCount: layout.columnCount
                )
                let maximum = max(visibleDays.map(\.messages).max() ?? 0, 1)
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(layout.cellSize), spacing: Self.activityCellSpacing),
                        count: layout.columnCount
                    ),
                    spacing: Self.activityCellSpacing
                ) {
                    ForEach(visibleDays) { day in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(levelColor(day.messages, maximum: maximum))
                            .frame(width: layout.cellSize, height: layout.cellSize)
                            .help("\(Self.dayFormatter.string(from: day.date)): \(day.messages) \(L("Messages").lowercased())")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: Self.activityCellMaximumSize * CGFloat(Self.activityRowCount)
                + Self.activityCellSpacing * CGFloat(Self.activityRowCount - 1))
            HStack(spacing: 6) {
                Text(L("Less")).font(.caption2).foregroundStyle(.secondary)
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2).fill(levelColor(level, maximum: 4)).frame(width: 12, height: 12)
                }
                Text(L("More")).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func activityGridLayout(
        for width: CGFloat,
        availableDayCount: Int
    ) -> ActivityGridLayout {
        let availableWidth = max(width, Self.activityCellMinimumSize)
        let possibleColumns = max(
            1,
            Int(floor(
                (availableWidth + Self.activityCellSpacing)
                    / (Self.activityCellMinimumSize + Self.activityCellSpacing)
            ))
        )
        let columnCount = max(
            1,
            min(
                possibleColumns,
                Self.activityMaximumColumnCount,
                max(availableDayCount, 1)
            )
        )
        let visibleDayCount = min(
            max(availableDayCount, 0),
            columnCount * Self.activityRowCount
        )
        let cellSize = min(
            Self.activityCellMaximumSize,
            max(
                Self.activityCellMinimumSize,
                (availableWidth - CGFloat(columnCount - 1) * Self.activityCellSpacing)
                    / CGFloat(columnCount)
            )
        )
        return ActivityGridLayout(
            visibleDayCount: visibleDayCount,
            columnCount: columnCount,
            cellSize: cellSize
        )
    }

    private func columnMajorDays(
        _ days: [ActivityDay],
        columnCount: Int
    ) -> [ActivityDay] {
        guard !days.isEmpty else { return [] }
        let rowCount = min(Self.activityRowCount, days.count)
        return (0..<rowCount).flatMap { row in
            (0..<columnCount).compactMap { column in
                let index = column * Self.activityRowCount + row
                return index < days.count ? days[index] : nil
            }
        }
    }

    private struct ActivityGridLayout {
        let visibleDayCount: Int
        let columnCount: Int
        let cellSize: CGFloat
    }

    private var tokenTrend: some View {
        let days = model.trendDays
        let totalTokens = days.reduce(0) { $0 + $1.tokens }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(L("Token trend"), systemImage: "chart.xyaxis.line")
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 0)
                Text(String(format: L("Total (last 30 days): %@ tokens"), TokenCountFormat.compact(totalTokens)))
                    .font(.appMicro)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }
            ActivityTokenTrendChart(days: days)
                .frame(height: 132)
            if let peak = model.peakTokenDay {
                Text(String(
                    format: L("Peak day: %@ · %@ tokens"),
                    Self.dayFormatter.string(from: peak.date),
                    TokenCountFormat.compact(peak.tokens)
                ))
                .font(.appMicro)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.divider, lineWidth: 0.5)
        }
    }

    private func levelColor(_ value: Int, maximum: Int) -> Color {
        guard value > 0 else { return Color.secondary.opacity(0.12) }
        let level = min(4, max(1, Int((Double(value) / Double(maximum) * 4).rounded(.up))))
        return Color.green.opacity(0.18 + Double(level) * 0.18)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

/// Historical days do not change. Keeping them in a compact local JSON cache
/// preserves the legacy plugin's fast reload behaviour without a KernelLumi or
/// SwiftData dependency. The current day always comes from MessageManaging.
public actor ActivityHeatmapCache {
    public struct Counts: Codable, Sendable, Equatable {
        public let messages: Int
        public let tokens: Int
    }

    /// 持久化格式 v3：日期分桶与写入时的时区绑定（#504）。
    private struct Envelope: Codable {
        let timeZoneIdentifier: String
        let counts: [String: Counts]
    }

    private let url: URL?
    private var values: [String: Counts]?
    private var loadedTimeZoneIdentifier: String?
    /// 当前时区。测试注入固定值以模拟时区切换（#504）。
    let timeZoneProvider: () -> TimeZone

    public init(directory: URL?, timeZoneProvider: @escaping () -> TimeZone = { TimeZone.current }) {
        self.url = directory?.appendingPathComponent("activity-cache-v3.json")
        self.timeZoneProvider = timeZoneProvider
        // v2 缓存不带时区标识，不再读取；删除避免过期残留。
        if let directory {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("activity-cache-v2.json"))
        }
    }

    public func counts(for dates: [Date]) -> [Date: Counts] {
        let stored = loadIfNeeded()
        let calendar = Calendar.current
        return Dictionary(uniqueKeysWithValues: dates.compactMap { date in
            stored[key(for: date, calendar: calendar)].map { (calendar.startOfDay(for: date), $0) }
        })
    }

    public func save(_ updates: [Date: Counts]) {
        guard !updates.isEmpty else { return }
        var stored = loadIfNeeded()
        let calendar = Calendar.current
        for (date, counts) in updates { stored[key(for: date, calendar: calendar)] = counts }
        values = stored
        guard let url else { return }
        let envelope = Envelope(timeZoneIdentifier: timeZoneProvider().identifier, counts: stored)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// 读取缓存，并在时区变化时整体失效（#504）。
    ///
    /// 日期分桶（`yyyy-MM-dd`）依赖写入时的时区：同一条消息在
    /// `America/Los_Angeles` 属于 1 月 1 日，切换到 `Asia/Shanghai` 后属于
    /// 1 月 2 日。若沿用旧分桶，同一条消息会同时出现在旧日期缓存与
    /// 当前查询里，被永久双计。因此无论内存缓存还是磁盘信封，时区
    /// 与当前不符时一律视为空，触发全量重查并以当前时区重写。
    private func loadIfNeeded() -> [String: Counts] {
        let currentIdentifier = timeZoneProvider().identifier
        if let values, loadedTimeZoneIdentifier == currentIdentifier {
            return values
        }
        let diskCounts: [String: Counts] = {
            guard let url,
                  let data = try? Data(contentsOf: url),
                  let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
                  envelope.timeZoneIdentifier == currentIdentifier
            else { return [:] }
            return envelope.counts
        }()
        values = diskCounts
        loadedTimeZoneIdentifier = currentIdentifier
        return diskCounts
    }

    private func key(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

private struct IdleTimeSummaryCard: View {
    @ObservedObject var state: ActivityHeatmapIdleTimeState

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L("Idle time"), systemImage: "moon.zzz").font(.headline)
            if let snapshot = state.snapshot {
                HStack(spacing: 8) {
                    Text(L("Rest window")).font(.caption).foregroundStyle(.secondary)
                    Text(restWindow(snapshot)).font(.subheadline.weight(.medium)).monospacedDigit()
                    Spacer()
                }
                if !snapshot.bucketScores.isEmpty {
                    IdleActivityTimeline(
                        scores: snapshot.bucketScores,
                        restWindow: snapshot.restWindow
                    )
                }
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task { state.refresh() }
    }

    private func restWindow(_ snapshot: IdleInferenceSnapshot) -> String {
        guard let window = snapshot.restWindow else { return L("Learning") }
        func time(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
        return "\(time(window.startMinuteOfDay)) – \(time(window.endMinuteOfDay))"
    }
}

/// Explains the 48 half-hour activity buckets used by idle-time inference.
private struct IdleActivityTimeline: View {
    let scores: [Double]
    let restWindow: RestWindow?

    private static let chartHeight: CGFloat = 92
    private static let yAxisWidth: CGFloat = 38
    private static let bucketCount = RestWindowInferencer.bucketsPerDay
    private static let bucketMinutes = RestWindowInferencer.bucketMinutes
    private static let timeLabels = [0, 6, 12, 18, 24]

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Relative activity strength"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                yAxis
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { proxy in
                        plot(in: proxy.size)
                    }
                    .frame(height: Self.chartHeight)
                    timeAxis
                }
            }

            HStack(spacing: 12) {
                legendSwatch(color: Color.accentColor.opacity(0.72), text: L("Activity"))
                legendSwatch(color: Color.accentColor.opacity(0.10), text: L("Shaded area = rest window"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var yAxis: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("100%")
            Spacer()
            Text("50%")
            Spacer()
            Text("0%")
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: Self.yAxisWidth, height: Self.chartHeight)
    }

    private var timeAxis: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.timeLabels.enumerated()), id: \.offset) { index, hour in
                Text(String(format: "%02d:00", hour))
                    .frame(maxWidth: .infinity, alignment: axisAlignment(for: index))
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private func axisAlignment(for index: Int) -> Alignment {
        switch index {
        case 0: return .leading
        case Self.timeLabels.count - 1: return .trailing
        default: return .center
        }
    }

    private func plot(in size: CGSize) -> some View {
        let maximum = max(scores.max() ?? 0, 1)

        return ZStack(alignment: .bottomLeading) {
            ForEach([0.0, 0.5, 1.0], id: \.self) { level in
                Rectangle()
                    .fill(Color.secondary.opacity(level == 0 ? 0.34 : 0.16))
                    .frame(height: 1)
                    .offset(y: -size.height * CGFloat(level))
            }

            ForEach(Array(restSegments.enumerated()), id: \.offset) { _, segment in
                Rectangle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(
                        width: size.width * CGFloat(segment.end - segment.start) / 1440,
                        height: size.height
                    )
                    .offset(x: size.width * CGFloat(segment.start) / 1440)
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<Self.bucketCount, id: \.self) { index in
                    let normalized = normalizedScore(at: index, maximum: maximum)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.accentColor.opacity(0.20 + 0.80 * normalized))
                        .frame(
                            maxWidth: .infinity,
                            minHeight: normalized > 0 ? 4 : 2,
                            maxHeight: max(2, size.height * CGFloat(normalized))
                        )
                        .help(bucketDescription(at: index, normalized: normalized))
                        .accessibilityLabel(bucketDescription(at: index, normalized: normalized))
                }
            }
            .padding(.horizontal, 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .clipped()
    }

    private var restSegments: [(start: Int, end: Int)] {
        guard let restWindow else { return [] }
        let start = max(0, min(1440, restWindow.startMinuteOfDay))
        let end = max(0, min(1440, restWindow.endMinuteOfDay))
        if start < end { return [(start, end)] }
        if start > end { return [(start, 1440), (0, end)] }
        return []
    }

    private func normalizedScore(at index: Int, maximum: Double) -> Double {
        guard scores.indices.contains(index), maximum > 0 else { return 0 }
        return min(1, max(0, scores[index] / maximum))
    }

    private func bucketDescription(at index: Int, normalized: Double) -> String {
        let start = index * Self.bucketMinutes
        let end = start + Self.bucketMinutes
        let percent = Int((normalized * 100).rounded())
        return "\(formatMinute(start))–\(formatMinute(end)) · \(L("Relative activity strength")): \(percent)%"
    }

    private func formatMinute(_ minute: Int) -> String {
        let normalizedMinute = minute % 1440
        return String(format: "%02d:%02d", normalizedMinute / 60, normalizedMinute % 60)
    }

    private func legendSwatch(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
        }
    }
}

private struct ActivityHeatmapAboutView: View {
    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(L("Activity Heatmap"), systemImage: "chart.bar.xaxis")
                    .font(.title2.weight(.semibold))
                Text(L("See your conversation rhythm over the last 30 days, 90 days, or year. The heatmap shows daily message activity while the trend chart summarizes token consumption."))
                    .foregroundStyle(.secondary)
                feature(L("Privacy-first"), L("All statistics are calculated from your local message database."), symbol: "lock")
                feature(L("Always current"), L("The dashboard refreshes as new messages arrive."), symbol: "arrow.clockwise")
                feature(L("Activity context"), L("Idle-time patterns and inferred rest windows help interpret your activity."), symbol: "moon.zzz")
            }
            .padding(24)
        }
    }

    private func feature(_ title: String, _ detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 18).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
