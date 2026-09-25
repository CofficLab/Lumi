import Foundation
import SwiftUI

public struct SystemBenchmarkSettingsView: View {
    @StateObject private var viewModel = SystemBenchmarkViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Text(BenchmarkLocalization.string("Tests run locally and do not use the network. Disk tests use a temporary file that is removed after the test."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if viewModel.isRunning {
                    runningSection
                } else {
                    Button {
                        viewModel.start()
                    } label: {
                        Label(BenchmarkLocalization.string("Start Test"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }

                if let report = viewModel.report {
                    reportSection(report)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(BenchmarkLocalization.string("System Benchmark"))
                .font(.title2.weight(.semibold))
            Text(BenchmarkLocalization.string("Measure CPU compute, memory bandwidth, and sequential disk throughput."))
                .foregroundStyle(.secondary)
        }
    }

    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: viewModel.progress.fraction)
            HStack {
                Text(progressTitle(viewModel.progress))
                    .font(.body.weight(.medium))
                Spacer()
                Button(BenchmarkLocalization.string("Cancel")) {
                    viewModel.cancel()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func reportSection(_ report: BenchmarkReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(BenchmarkLocalization.string("Latest Result"))
                .font(.headline)

            ForEach(BenchmarkKind.allCases) { kind in
                let measurements = report.measurements.filter { $0.kind == kind }
                if !measurements.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kindTitle(kind))
                            .font(.subheadline.weight(.semibold))
                        ForEach(measurements) { measurement in
                            measurementRow(measurement)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func measurementRow(_ measurement: BenchmarkMeasurement) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(labelTitle(measurement.label))
            Spacer()
            Text(String(format: "%.1f %@", measurement.value, measurement.unit))
                .font(.body.monospacedDigit().weight(.medium))
            Text(String(format: "%.0f ms", measurement.durationMilliseconds))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help(measurement.detail)
    }

    private func progressTitle(_ progress: BenchmarkProgress) -> String {
        switch progress {
        case .preparing: return BenchmarkLocalization.string("Preparing")
        case .cpu: return BenchmarkLocalization.string("Testing CPU")
        case .memory: return BenchmarkLocalization.string("Testing Memory")
        case .disk: return BenchmarkLocalization.string("Testing Disk")
        case .finished: return BenchmarkLocalization.string("Finished")
        }
    }

    private func kindTitle(_ kind: BenchmarkKind) -> String {
        switch kind {
        case .cpu: return BenchmarkLocalization.string("CPU")
        case .memory: return BenchmarkLocalization.string("Memory Bandwidth")
        case .disk: return BenchmarkLocalization.string("Disk Throughput")
        }
    }

    private func labelTitle(_ label: String) -> String {
        switch label {
        case "single-core": return BenchmarkLocalization.string("Single Core")
        case "multi-core": return BenchmarkLocalization.string("Multi Core")
        case "write": return BenchmarkLocalization.string("Write")
        case "read": return BenchmarkLocalization.string("Read")
        case "copy": return BenchmarkLocalization.string("Copy")
        default: return label
        }
    }
}
