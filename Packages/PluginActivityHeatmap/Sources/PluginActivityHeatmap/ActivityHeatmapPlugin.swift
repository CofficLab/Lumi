import Foundation
import GitPlugin
import KernelCore
import KitLocalization
import LumiUI
import ProviderMessage
import ProviderActivityHeatmap
import ProviderGitRepositoryWatch
import ProviderSettingView
import ProviderIdleTime
import ProviderDocsView
import ProviderStorage
import SwiftUI
import KitSuperLog
import os

/// V2 activity dashboard. It preserves the legacy heatmap's three time ranges,
/// daily message intensity, token trend, and persisted range preference while
/// consuming only KernelCore providers.
@MainActor
public final class ActivityHeatmapPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.activity-heatmap", category: "ActivityHeatmap")
    public let id = "com.coffic.activity-heatmap"
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

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let provider = LocalGitActivityHeatmapProvider(
                directory: storage.pluginDataDirectory(for: id)
            )
            gitActivityProvider = provider
            try kernel.registerProvider((any ActivityHeatmapProviding).self, provider)

            if let gitWatch = kernel.resolveProvider((any GitRepositoryWatching).self) {
                gitWatchHandle = gitWatch.addObserver { [weak provider, weak gitWatch] event in
                    guard case .refsChanged = event,
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
            .pluginDataDirectory(for: "ActivityHeatmap")
        ActivityHeatmapViewModel.restoreLegacyPeriodIfNeeded(from: directory)
        cache = ActivityHeatmapCache(directory: directory)
        let viewModel = ActivityHeatmapViewModel(messages: messages, cache: cache)
        self.viewModel = viewModel
        if let messages {
            insertionObserver = MessageObserver(messages: messages) { [weak self] in
                Task { @MainActor in
                    await self?.viewModel?.reload()
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
                title: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
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
                DocsEntry(id: id, name: LumiPluginLocalization.string("Activity Heatmap", bundle: .module)) { ActivityHeatmapAboutView() }
            )
            docs.addManual(
                DocsEntry(id: id, name: LumiPluginLocalization.string("Activity Heatmap", bundle: .module)) { ActivityHeatmapManualView() }
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
        case .days30: LumiPluginLocalization.string("Last 30 days", bundle: .module)
        case .days90: LumiPluginLocalization.string("Last 90 days", bundle: .module)
        case .year: LumiPluginLocalization.string("Last year", bundle: .module)
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
@Observable
public final class ActivityHeatmapViewModel {
    private let messages: (any MessageManaging)?
    private let cache: ActivityHeatmapCache?
    private var reloadTask: Task<Void, Never>?
    private var reloadGeneration = 0
    static let periodKey = "com.coffic.activity-heatmap.period"

    public var period: ActivityHeatmapPeriod {
        didSet { UserDefaults.standard.set(period.rawValue, forKey: Self.periodKey) }
    }
    public private(set) var days: [ActivityDay] = []
    /// The heatmap keeps a full year's daily history so its layout can decide
    /// how much to show from the available space independently of `period`.
    public private(set) var heatmapDays: [ActivityDay] = []
    public private(set) var isLoading = false
    /// The day with the highest token consumption, shown next to the trend
    /// total. Nil when no tokens were consumed in the tracked year.
    public var peakTokenDay: ActivityDay? {
        heatmapDays.max { $0.tokens < $1.tokens }.flatMap { $0.tokens > 0 ? $0 : nil }
    }

    public init(messages: (any MessageManaging)?, cache: ActivityHeatmapCache? = nil) {
        self.messages = messages
        self.cache = cache
        self.period = ActivityHeatmapPeriod(rawValue: UserDefaults.standard.integer(forKey: Self.periodKey)) ?? .days30
    }

    static func restoreLegacyPeriodIfNeeded(from directory: URL?) {
        guard UserDefaults.standard.object(forKey: periodKey) == nil,
              let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("settings/settings.json")),
              let legacy = try? JSONDecoder().decode(LegacyPeriodPreference.self, from: data),
              let rawValue = legacy.selectedPeriodRawValue,
              ActivityHeatmapPeriod(rawValue: rawValue) != nil
        else { return }
        UserDefaults.standard.set(rawValue, forKey: periodKey)
    }

    public func reload() async {
        reloadTask?.cancel()
        reloadTask = nil
        await reloadNow()
    }

    private func scheduleReload() {
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
        let today = calendar.startOfDay(for: Date())
        let heatmapDayCount = ActivityHeatmapPeriod.year.rawValue
        guard let start = calendar.date(byAdding: .day, value: -(heatmapDayCount - 1), to: today) else {
            isLoading = false
            return
        }
        let historicalDates = (0..<(heatmapDayCount - 1)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
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
    @State private var model: ActivityHeatmapViewModel
    private let idleTime: (any IdleTimeProviding)?
    private let idleTimeState: ActivityHeatmapIdleTimeState

    private static let activityCellMinimumSize: CGFloat = 10
    private static let activityCellMaximumSize: CGFloat = 14
    private static let activityCellSpacing: CGFloat = 4
    private static let activityRowCount = 7
    private static let activityMaximumColumnCount = 53

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    public init(
        model: ActivityHeatmapViewModel,
        idleTime: (any IdleTimeProviding)? = nil,
        idleTimeState: ActivityHeatmapIdleTimeState? = nil
    ) {
        _model = State(initialValue: model)
        self.idleTime = idleTime
        self.idleTimeState = idleTimeState ?? ActivityHeatmapIdleTimeState(provider: idleTime)
    }

    public init(
        messages: (any MessageManaging)?,
        idleTime: (any IdleTimeProviding)? = nil,
        cache: ActivityHeatmapCache? = nil
    ) {
        _model = State(initialValue: ActivityHeatmapViewModel(messages: messages, cache: cache))
        self.idleTime = idleTime
        self.idleTimeState = ActivityHeatmapIdleTimeState(provider: idleTime)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summary
                heatmap
                tokenTrend
                if idleTime != nil {
                    IdleTimeSummaryCard(state: idleTimeState)
                }
            }
            .padding(24)
        }
        .task { await model.reload() }
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
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Token trend")).font(.headline)
            GeometryReader { proxy in
                let maxTokens = max(model.heatmapDays.map(\.tokens).max() ?? 0, 1)
                let width = max(proxy.size.width, 1)
                let height = max(proxy.size.height, 1)
                Path { path in
                    for (index, day) in model.heatmapDays.enumerated() {
                        let x = model.heatmapDays.count < 2
                            ? width / 2
                            : width * CGFloat(index) / CGFloat(model.heatmapDays.count - 1)
                        let y = height - height * CGFloat(day.tokens) / CGFloat(maxTokens)
                        index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(.orange, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            }
            .frame(height: 120)
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: L("Total: %@ tokens"), TokenCountFormat.compact(model.heatmapDays.reduce(0) { $0 + $1.tokens })))
                Spacer()
                if let peak = model.peakTokenDay {
                    Text(String(
                        format: L("Peak day: %@ · %@ tokens"),
                        Self.dayFormatter.string(from: peak.date),
                        TokenCountFormat.compact(peak.tokens)
                    ))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private let url: URL?
    private var values: [String: Counts]?
    private let calendar = Calendar.current

    public init(directory: URL?) {
        self.url = directory?.appendingPathComponent("activity-cache-v2.json")
    }

    public func counts(for dates: [Date]) -> [Date: Counts] {
        let stored = loadIfNeeded()
        return Dictionary(uniqueKeysWithValues: dates.compactMap { date in
            stored[key(for: date)].map { (calendar.startOfDay(for: date), $0) }
        })
    }

    public func save(_ updates: [Date: Counts]) {
        guard !updates.isEmpty else { return }
        var stored = loadIfNeeded()
        for (date, counts) in updates { stored[key(for: date)] = counts }
        values = stored
        guard let url, let data = try? JSONEncoder().encode(stored) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private func loadIfNeeded() -> [String: Counts] {
        if let values { return values }
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Counts].self, from: data)
        else { values = [:]; return [:] }
        values = decoded
        return decoded
    }

    private func key(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

private struct IdleTimeSummaryCard: View {
    @ObservedObject var state: ActivityHeatmapIdleTimeState

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
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
        LumiPluginLocalization.string(key, bundle: .module)
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
        LumiPluginLocalization.string(key, bundle: .module)
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
