import Foundation
import LumiUI
import SwiftUI

/// Full benchmark dashboard used by both Settings and the Activity Bar entry.
public struct SystemBenchmarkSettingsView: View {
    @ObservedObject private var viewModel: SystemBenchmarkViewModel

    public init(viewModel: SystemBenchmarkViewModel = SystemBenchmarkViewModel()) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        SystemBenchmarkDashboardView(viewModel: viewModel)
    }
}

/// Main Activity Bar content for the local system benchmark plugin.
public struct SystemBenchmarkView: View {
    @ObservedObject private var viewModel: SystemBenchmarkViewModel

    public init(viewModel: SystemBenchmarkViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        SystemBenchmarkDashboardView(viewModel: viewModel)
    }
}

private struct SystemBenchmarkDashboardView: View {
    @LumiTheme private var theme
    @ObservedObject var viewModel: SystemBenchmarkViewModel

    var body: some View {
        PluginSettingsScaffold(
            title: BenchmarkLocalization.string("System Benchmark"),
            subtitle: BenchmarkLocalization.string("A focused local performance report for this Mac.")
        ) {
            VStack(alignment: .leading, spacing: 20) {
                hero

                if viewModel.isRunning {
                    progressCard
                }

                if let errorMessage = viewModel.errorMessage {
                    AppStatusBanner(
                        kind: .error,
                        title: BenchmarkLocalization.string("Benchmark failed"),
                        message: errorMessage
                    )
                }

                suiteOverview

                if let report = viewModel.report {
                    resultsSection(report)
                } else {
                    emptyResults
                }

                methodCard
            }
        }
        .environment(\.appSettingsCardStyleOverride, .subtle)
    }

    private var hero: some View {
        AppCard(
            style: .elevated,
            cornerRadius: 18,
            glowColor: viewModel.isRunning ? theme.primary : nil
        ) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.primary.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(theme.primary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(BenchmarkLocalization.string("System Benchmark"))
                        .font(.appTitle)
                        .foregroundStyle(theme.textPrimary)
                    Text(BenchmarkLocalization.string("CPU, memory bandwidth, and sequential disk throughput"))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                    AppTag(
                        viewModel.isRunning
                            ? BenchmarkLocalization.string("Running")
                            : BenchmarkLocalization.string("Ready"),
                        systemImage: viewModel.isRunning ? "waveform" : "checkmark.circle",
                        style: viewModel.isRunning ? .accent : .subtle
                    )
                }

                Spacer(minLength: 12)

                if viewModel.isRunning {
                    AppButton(
                        BenchmarkLocalization.string("Cancel"),
                        systemImage: "stop.fill",
                        style: .destructive,
                        size: .small
                    ) {
                        viewModel.cancel()
                    }
                } else {
                    AppButton(
                        BenchmarkLocalization.string("Start Benchmark"),
                        systemImage: "play.fill",
                        style: .primary,
                        size: .medium
                    ) {
                        viewModel.start()
                    }
                }
            }
        }
    }

    private var progressCard: some View {
        AppCard(style: .subtle, showShadow: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(progressTitle, systemImage: progressIcon)
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.progress.fraction * 100))
                        .font(.appMonoCaption)
                        .foregroundStyle(theme.primary)
                }

                ProgressView(value: viewModel.progress.fraction)
                    .tint(theme.primary)

                Text(BenchmarkLocalization.string("The test runs locally and can be cancelled at any stage."))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var suiteOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionLabel(BenchmarkLocalization.string("Benchmark suite"))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(BenchmarkKind.allCases) { kind in
                    BenchmarkSuiteCard(
                        kind: kind,
                        measurements: viewModel.report?.measurements.filter { $0.kind == kind } ?? []
                    )
                }
            }
        }
    }

    private var emptyResults: some View {
        AppCard(style: .subtle, showShadow: false) {
            AppEmptyState(
                icon: "chart.bar.xaxis",
                title: BenchmarkLocalization.string("No benchmark yet"),
                description: BenchmarkLocalization.string("Run a test to see the measured throughput for this Mac.")
            )
            .frame(maxWidth: .infinity)
        }
    }

    private func resultsSection(_ report: BenchmarkReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                AppSectionLabel(BenchmarkLocalization.string("Latest result"))
                Spacer()
                Text(Self.dateFormatter.string(from: report.generatedAt))
                    .font(.appCaption)
                    .foregroundStyle(theme.textTertiary)
            }

            AppCard(style: .subtle, showShadow: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(BenchmarkKind.allCases) { kind in
                        let measurements = report.measurements.filter { $0.kind == kind }
                        if !measurements.isEmpty {
                            BenchmarkResultGroup(kind: kind, measurements: measurements)
                        }
                    }
                }
            }
        }
    }

    private var methodCard: some View {
        AppCard(style: .subtle, showShadow: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(theme.info)
                    Text(BenchmarkLocalization.string("About this test"))
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                }

                AppSettingsSection(spacing: 10) {
                    AppSettingsRow {
                        AppInfoRow(
                            icon: "cpu",
                            title: BenchmarkLocalization.string("CPU compute"),
                            description: BenchmarkLocalization.string("Fixed integer workload measured as operations per second."),
                            tint: theme.info
                        )
                    }
                    AppSettingsRow {
                        AppInfoRow(
                            icon: "memorychip",
                            title: BenchmarkLocalization.string("Memory bandwidth"),
                            description: BenchmarkLocalization.string("Sequential write, copy, and read passes over a fixed buffer."),
                            tint: theme.success
                        )
                    }
                    AppSettingsRow {
                        AppInfoRow(
                            icon: "internaldrive",
                            title: BenchmarkLocalization.string("Disk throughput"),
                            description: BenchmarkLocalization.string("Sequential I/O against a temporary file; the file is removed afterwards."),
                            tint: theme.warning
                        )
                    }
                }

                Text(BenchmarkLocalization.string("Network testing is intentionally not included in this version."))
                    .font(.appCaption)
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private var progressTitle: String {
        switch viewModel.progress {
        case .preparing: return BenchmarkLocalization.string("Preparing")
        case .cpu: return BenchmarkLocalization.string("Testing CPU")
        case .memory: return BenchmarkLocalization.string("Testing Memory")
        case .disk: return BenchmarkLocalization.string("Testing Disk")
        case .finished: return BenchmarkLocalization.string("Finished")
        }
    }

    private var progressIcon: String {
        switch viewModel.progress {
        case .preparing: return "ellipsis"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .finished: return "checkmark.circle"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct BenchmarkSuiteCard: View {
    @LumiTheme private var theme

    let kind: BenchmarkKind
    let measurements: [BenchmarkMeasurement]

    var body: some View {
        AppCard(style: .subtle, padding: EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14), showShadow: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: kind.icon)
                        .foregroundStyle(kind.color(in: theme))
                    Text(kind.title)
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    AppTag(
                        measurements.isEmpty
                            ? BenchmarkLocalization.string("Pending")
                            : BenchmarkLocalization.string("Measured"),
                        style: measurements.isEmpty ? .subtle : .accent
                    )
                }

                if measurements.isEmpty {
                    Text(BenchmarkLocalization.string("Ready to test"))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text(summaryMeasurement.valueText)
                        .font(.appSectionTitle)
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text(summaryMeasurement.label)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var summaryMeasurement: (valueText: String, label: String) {
        let measurement = measurements.first(where: { $0.label == preferredLabel }) ?? measurements.first!
        return (formatted(measurement), measurement.label.capitalized)
    }

    private var preferredLabel: String {
        switch kind {
        case .cpu: return "multi-core"
        case .memory: return "copy"
        case .disk: return "read"
        }
    }

    private func formatted(_ measurement: BenchmarkMeasurement) -> String {
        String(format: "%.1f %@", measurement.value, measurement.unit)
    }
}

private struct BenchmarkResultGroup: View {
    @LumiTheme private var theme

    let kind: BenchmarkKind
    let measurements: [BenchmarkMeasurement]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(kind.title, systemImage: kind.icon)
                    .font(.appBodyEmphasized)
                    .foregroundStyle(kind.color(in: theme))
                Spacer()
                Text(kind.unit)
                    .font(.appCaption)
                    .foregroundStyle(theme.textTertiary)
            }

            AppBarChart(data: chartData)

            ForEach(measurements) { measurement in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(measurement.label.capitalized)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f %@", measurement.value, measurement.unit))
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text(String(format: "%.0f ms", measurement.durationMilliseconds))
                        .font(.appCaption)
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var chartData: AppBarChartData {
        AppBarChartData(
            title: BenchmarkLocalization.string("Relative throughput"),
            totalText: "\(measurements.count)",
            peakText: String(format: "%.1f %@", measurements.map(\.value).max() ?? 0, kind.unit),
            bars: measurements.map { measurement in
                AppBarChartData.Bar(
                    value: Int(min(max(measurement.value, 0), Double(Int.max))),
                    isHighlighted: measurement.label == preferredLabel,
                    tooltip: "\(measurement.label): \(measurement.value) \(measurement.unit)"
                )
            },
            accessibilitySummary: BenchmarkLocalization.string("Benchmark result chart")
        )
    }

    private var preferredLabel: String {
        switch kind {
        case .cpu: return "multi-core"
        case .memory: return "copy"
        case .disk: return "read"
        }
    }
}

private extension BenchmarkKind {
    var title: String {
        switch self {
        case .cpu: return BenchmarkLocalization.string("CPU")
        case .memory: return BenchmarkLocalization.string("Memory")
        case .disk: return BenchmarkLocalization.string("Disk")
        }
    }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        }
    }

    var unit: String {
        switch self {
        case .cpu: return "ops/s"
        case .memory, .disk: return "MiB/s"
        }
    }

    func color(in theme: any LumiUITheme) -> Color {
        switch self {
        case .cpu: return theme.info
        case .memory: return theme.success
        case .disk: return theme.warning
        }
    }
}
