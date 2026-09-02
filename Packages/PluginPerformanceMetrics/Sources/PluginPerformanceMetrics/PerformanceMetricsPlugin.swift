import KernelCore
import ProviderPerformanceMetrics
import ProviderSettingView
import ProviderStorage
import SwiftUI

/// Registers the shared performance collector and exposes its local report in Settings.
@MainActor
public final class PerformanceMetricsPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.performance-metrics"
    public let order = 5
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.performance-metrics",
        name: "Performance Metrics",
        description: "Collect local plugin performance timings.",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    private var provider: DefaultPerformanceMetricsProvider?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let directory = kernel.resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: "PerformanceMetrics")
        let provider = DefaultPerformanceMetricsProvider(directoryURL: directory)
        try kernel.registerProvider((any PerformanceMetricsProviding).self, provider)
        self.provider = provider

        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: id,
                title: "Performance Metrics",
                systemImage: "gauge.with.dots.needle.67percent",
                order: order
            ) {
                PerformanceMetricsSettingsView(provider: provider)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
        provider = nil
    }
}

public struct PerformanceMetricsSettingsView: View {
    private let provider: any PerformanceMetricsProviding

    @State private var report: PerformanceMetricsReport?
    @State private var isLoading = false

    public init(provider: any PerformanceMetricsProviding) {
        self.provider = provider
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if isLoading && report == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let report, !report.summaries.isEmpty {
                    Text("Latency summaries")
                        .font(.headline)

                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(report.summaries) { summary in
                            summaryRow(summary)
                        }
                    }

                    Text("Recent samples: \(report.totalEventCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !isLoading {
                    ContentUnavailableView(
                        "No performance data",
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text("Use the app normally and timings will appear here.")
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .task { await reload() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Metrics")
                    .font(.title2.weight(.semibold))
                Text("Local timings reported by app plugins. Message content is never collected.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Clear") {
                    provider.clear()
                    Task { await reload() }
                }
                .disabled(isLoading)

                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh performance data")
            }
        }
    }

    private func summaryRow(_ summary: PerformanceMetricSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(summary.operation) / \(summary.stage)")
                    .font(.body.weight(.medium))
                Spacer()
                Text("n=\(summary.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                value("P50", summary.p50Milliseconds)
                value("P95", summary.p95Milliseconds)
                value("P99", summary.p99Milliseconds)
                value("Max", summary.maxMilliseconds)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func value(_ label: String, _ milliseconds: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(format(milliseconds))
                .font(.body.monospacedDigit())
        }
    }

    private func format(_ milliseconds: Double) -> String {
        if milliseconds < 1 {
            return String(format: "%.2f ms", milliseconds)
        }
        return String(format: "%.1f ms", milliseconds)
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        let nextReport = await provider.report()
        guard !Task.isCancelled else { return }
        report = nextReport
    }
}
