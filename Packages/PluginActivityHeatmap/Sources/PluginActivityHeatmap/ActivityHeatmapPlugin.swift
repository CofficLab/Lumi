import Foundation
import KernelCore
import KitLocalization
import ProviderMessage
import ProviderSettingView
import ProviderIdleTime
import ProviderDocsView
import ProviderStorage
import SwiftUI
#if canImport(AppKit)
import AppKit
import KitSuperLog
import os
#endif

/// V2 activity dashboard. It preserves the legacy heatmap's three time ranges,
/// daily message intensity, token trend, and persisted range preference while
/// consuming only KernelCore providers.
@MainActor
public final class ActivityHeatmapPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.activity-heatmap", category: "ActivityHeatmap")
    public let id = "com.coffic.activity-heatmap"
    public let order = 9
    public let metadata = PluginMetadata(
        id: "com.coffic.activity-heatmap",
        name: "Activity Heatmap",
        description: "Display daily conversation activity and token consumption.",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    private var cache: ActivityHeatmapCache?
    private var cacheDirectory: URL?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
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
        cacheDirectory = directory
        cache = ActivityHeatmapCache(directory: directory)
        settings.addEntries([
            SettingEntryItem(
                id: id,
                title: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
                systemImage: "chart.bar.xaxis",
                order: order
            ) {
                ActivityHeatmapSettingsView(
                    messages: messages,
                    idleTime: idleTime,
                    cache: self.cache,
                    cacheDirectory: directory
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
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
        cache = nil
        cacheDirectory = nil
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
    private var insertionObserver: MessageObserver?
    private var reloadTask: Task<Void, Never>?
    private var reloadGeneration = 0
    static let periodKey = "com.coffic.activity-heatmap.period"

    public var period: ActivityHeatmapPeriod {
        didSet { UserDefaults.standard.set(period.rawValue, forKey: Self.periodKey) }
    }
    public private(set) var days: [ActivityDay] = []
    public private(set) var isLoading = false

    public init(messages: (any MessageManaging)?, cache: ActivityHeatmapCache? = nil) {
        self.messages = messages
        self.cache = cache
        self.period = ActivityHeatmapPeriod(rawValue: UserDefaults.standard.integer(forKey: Self.periodKey)) ?? .days30
        insertionObserver = messages.map { messages in MessageObserver(messages: messages) { [weak self] in
            self?.scheduleReload()
        } }
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
        guard let messages else { days = []; return }
        isLoading = true
        defer {
            if generation == reloadGeneration {
                isLoading = false
            }
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(period.rawValue - 1), to: today) else {
            isLoading = false
            return
        }
        let historicalDates = (0..<(period.rawValue - 1)).compactMap {
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
        days = (0..<period.rawValue).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let isToday = date == today
            let cachedDay = cached[date]
            return ActivityDay(
                date: date,
                messages: isToday ? todayMessages[date, default: 0] : cachedDay?.messages ?? historical[date]?.messages ?? 0,
                tokens: isToday ? todayTokens[date, default: 0] : cachedDay?.tokens ?? historical[date]?.tokens ?? 0
            )
        }
    }
}

private struct LegacyPeriodPreference: Decodable {
    let selectedPeriodRawValue: Int?
}

public struct ActivityHeatmapSettingsView: View {
    @State private var model: ActivityHeatmapViewModel
    private let idleTime: (any IdleTimeProviding)?

    private let cacheDirectory: URL?

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    public init(
        messages: (any MessageManaging)?,
        idleTime: (any IdleTimeProviding)? = nil,
        cache: ActivityHeatmapCache? = nil,
        cacheDirectory: URL? = nil
    ) {
        _model = State(initialValue: ActivityHeatmapViewModel(messages: messages, cache: cache))
        self.idleTime = idleTime
        self.cacheDirectory = cacheDirectory
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Activity Heatmap")).font(.title2.weight(.semibold))
                        Text(L("Conversation activity and token consumption over time.")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker(L("Period"), selection: $model.period) {
                        ForEach(ActivityHeatmapPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                    Button { Task { await model.reload() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help(L("Refresh activity"))
                }

                summary
                heatmap
                tokenTrend
                if let cacheDirectory { dataDirectoryButton(cacheDirectory) }
                if let idleTime {
                    IdleTimeSummaryCard(provider: idleTime)
                }
            }
            .padding(24)
        }
        .onChange(of: model.period) { _, _ in Task { await model.reload() } }
        .task { await model.reload() }
    }

    private var summary: some View {
        let totalMessages = model.days.reduce(0) { $0 + $1.messages }
        let totalTokens = model.days.reduce(0) { $0 + $1.tokens }
        let activeDays = model.days.filter { $0.messages > 0 }.count
        return HStack(spacing: 12) {
            metric(L("Messages"), value: "\(totalMessages)", symbol: "bubble.left.and.bubble.right")
            metric(L("Active days"), value: "\(activeDays)", symbol: "calendar")
            metric(L("Tokens"), value: formatted(totalTokens), symbol: "number")
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
            let maximum = max(model.days.map(\.messages).max() ?? 0, 1)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 14), spacing: 4) {
                ForEach(model.days) { day in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(levelColor(day.messages, maximum: maximum))
                        .frame(width: 14, height: 14)
                        .help("\(Self.dayFormatter.string(from: day.date)): \(day.messages) \(L("Messages").lowercased())")
                }
            }
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

    private var tokenTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Token trend")).font(.headline)
            GeometryReader { proxy in
                let maxTokens = max(model.days.map(\.tokens).max() ?? 0, 1)
                let width = max(proxy.size.width, 1)
                let height = max(proxy.size.height, 1)
                Path { path in
                    for (index, day) in model.days.enumerated() {
                        let x = model.days.count < 2 ? width / 2 : width * CGFloat(index) / CGFloat(model.days.count - 1)
                        let y = height - height * CGFloat(day.tokens) / CGFloat(maxTokens)
                        index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(.orange, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            }
            .frame(height: 120)
            Text(String(format: L("Total: %lld tokens"), model.days.reduce(0) { $0 + $1.tokens }))
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

    private func formatted(_ value: Int) -> String {
        value >= 1_000_000 ? String(format: "%.1fM", Double(value) / 1_000_000) : value >= 1_000 ? "\(value / 1_000)K" : "\(value)"
    }

    @ViewBuilder
    private func dataDirectoryButton(_ directory: URL) -> some View {
        #if canImport(AppKit)
        Button(L("Open Data Directory"), systemImage: "folder") {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(directory)
        }
        .buttonStyle(.bordered)
        #endif
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
    let provider: any IdleTimeProviding
    @State private var snapshot: IdleInferenceSnapshot?

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L("Idle time"), systemImage: "moon.zzz").font(.headline)
                Spacer()
                Text(L("Activity patterns and rest windows")).font(.caption).foregroundStyle(.secondary)
            }
            if let snapshot {
                HStack(spacing: 12) {
                    metric(L("Rest window"), value: restWindow(snapshot))
                    metric(L("Confidence"), value: snapshot.restWindow.map { "\(Int(($0.confidence * 100).rounded()))%" } ?? L("Learning"))
                    metric(L("Events"), value: "\(snapshot.eventCount)")
                    metric(L("Active days"), value: "\(snapshot.observedDayCount)")
                }
                if !snapshot.bucketScores.isEmpty {
                    HStack(alignment: .bottom, spacing: 2) {
                        let maximum = max(snapshot.bucketScores.max() ?? 0, 1)
                        ForEach(Array(snapshot.bucketScores.enumerated()), id: \.offset) { _, score in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor.opacity(0.2 + 0.8 * (score / maximum)))
                                .frame(maxWidth: .infinity, minHeight: 4, maxHeight: 56 * CGFloat(score / maximum) + 4)
                        }
                    }
                    .frame(height: 62, alignment: .bottom)
                }
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task { snapshot = await provider.currentSnapshot() }
        .onReceive(NotificationCenter.default.publisher(for: .idleTimeSnapshotDidChange)) { _ in
            Task { snapshot = await provider.currentSnapshot() }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func restWindow(_ snapshot: IdleInferenceSnapshot) -> String {
        guard let window = snapshot.restWindow else { return L("Learning") }
        func time(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
        return "\(time(window.startMinuteOfDay)) – \(time(window.endMinuteOfDay))"
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
