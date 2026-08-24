import Foundation
import KernelCore
import ProviderMessage
import ProviderSettingView
import ProviderIdleTime
import ProviderDocsView
import SwiftUI

/// V2 activity dashboard. It preserves the legacy heatmap's three time ranges,
/// daily message intensity, token trend, and persisted range preference while
/// consuming only KernelCore providers.
@MainActor
public final class ActivityHeatmapPlugin: SuperPlugin {
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

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else { return }
        let messages = kernel.resolveProvider((any MessageManaging).self)
        let idleTime = kernel.resolveProvider((any IdleTimeProviding).self)
        settings.addEntries([
            SettingEntryItem(
                id: id,
                title: "Activity Heatmap",
                systemImage: "chart.bar.xaxis",
                order: order
            ) {
                ActivityHeatmapSettingsView(messages: messages, idleTime: idleTime)
            },
        ])
        kernel.resolveProvider((any DocsViewProviding).self)?.addAbout(
            DocsEntry(id: id, name: "Activity Heatmap") { ActivityHeatmapAboutView() }
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
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
        case .days30: "Last 30 days"
        case .days90: "Last 90 days"
        case .year: "Last year"
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
    private var insertionObserver: (any MessageInsertedObserverHandle)?
    private static let periodKey = "com.coffic.activity-heatmap.period"

    public var period: ActivityHeatmapPeriod {
        didSet { UserDefaults.standard.set(period.rawValue, forKey: Self.periodKey) }
    }
    public private(set) var days: [ActivityDay] = []
    public private(set) var isLoading = false

    public init(messages: (any MessageManaging)?) {
        self.messages = messages
        self.period = ActivityHeatmapPeriod(rawValue: UserDefaults.standard.integer(forKey: Self.periodKey)) ?? .days30
        insertionObserver = messages?.addMessageInsertedObserver { [weak self] _, _ in
            self?.reload()
        }
    }

    public func reload() {
        guard let messages else { days = []; return }
        isLoading = true
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(period.rawValue - 1), to: today) else {
            isLoading = false
            return
        }
        let messageCounts = messages.dailyMessageCounts(since: start)
        let tokenCounts = messages.dailyTokenCounts(since: start)
        days = (0..<period.rawValue).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return ActivityDay(date: date, messages: messageCounts[date, default: 0], tokens: tokenCounts[date, default: 0])
        }
        isLoading = false
    }
}

public struct ActivityHeatmapSettingsView: View {
    @State private var model: ActivityHeatmapViewModel
    private let idleTime: (any IdleTimeProviding)?

    public init(messages: (any MessageManaging)?, idleTime: (any IdleTimeProviding)? = nil) {
        _model = State(initialValue: ActivityHeatmapViewModel(messages: messages))
        self.idleTime = idleTime
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity Heatmap").font(.title2.weight(.semibold))
                        Text("Conversation activity and token consumption over time.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Period", selection: $model.period) {
                        ForEach(ActivityHeatmapPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                    Button { model.reload() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh activity")
                }

                summary
                heatmap
                tokenTrend
                if let idleTime {
                    IdleTimeSummaryCard(provider: idleTime)
                }
            }
            .padding(24)
        }
        .onChange(of: model.period) { _, _ in model.reload() }
        .task { model.reload() }
    }

    private var summary: some View {
        let totalMessages = model.days.reduce(0) { $0 + $1.messages }
        let totalTokens = model.days.reduce(0) { $0 + $1.tokens }
        let activeDays = model.days.filter { $0.messages > 0 }.count
        return HStack(spacing: 12) {
            metric("Messages", value: "\(totalMessages)", symbol: "bubble.left.and.bubble.right")
            metric("Active days", value: "\(activeDays)", symbol: "calendar")
            metric("Tokens", value: formatted(totalTokens), symbol: "number")
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
            Text("Daily activity").font(.headline)
            let maximum = max(model.days.map(\.messages).max() ?? 0, 1)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 14), spacing: 4) {
                ForEach(model.days) { day in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(levelColor(day.messages, maximum: maximum))
                        .frame(width: 14, height: 14)
                        .help("\(Self.dayFormatter.string(from: day.date)): \(day.messages) messages")
                }
            }
            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2).fill(levelColor(level, maximum: 4)).frame(width: 12, height: 12)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tokenTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token trend").font(.headline)
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
            Text("Total: \(formatted(model.days.reduce(0) { $0 + $1.tokens })) tokens")
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

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

private struct IdleTimeSummaryCard: View {
    let provider: any IdleTimeProviding
    @State private var snapshot: IdleInferenceSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Idle time", systemImage: "moon.zzz").font(.headline)
                Spacer()
                Text("Activity patterns and rest windows").font(.caption).foregroundStyle(.secondary)
            }
            if let snapshot {
                HStack(spacing: 12) {
                    metric("Rest window", value: restWindow(snapshot))
                    metric("Confidence", value: snapshot.restWindow.map { "\(Int(($0.confidence * 100).rounded()))%" } ?? "Learning")
                    metric("Events", value: "\(snapshot.eventCount)")
                    metric("Active days", value: "\(snapshot.observedDayCount)")
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
        guard let window = snapshot.restWindow else { return "Learning" }
        func time(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
        return "\(time(window.startMinuteOfDay)) – \(time(window.endMinuteOfDay))"
    }
}

private struct ActivityHeatmapAboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Activity Heatmap", systemImage: "chart.bar.xaxis")
                    .font(.title2.weight(.semibold))
                Text("See your conversation rhythm over the last 30 days, 90 days, or year. The heatmap shows daily message activity while the trend chart summarizes token consumption.")
                    .foregroundStyle(.secondary)
                feature("Privacy-first", "All statistics are calculated from your local message database.", symbol: "lock")
                feature("Always current", "The dashboard refreshes as new messages arrive.", symbol: "arrow.clockwise")
                feature("Activity context", "Idle-time patterns and inferred rest windows help interpret your activity.", symbol: "moon.zzz")
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
