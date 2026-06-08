import Foundation
import LumiCoreKit
import LumiUI
import SwiftUI

public enum DiskManagerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .system
    public static let iconName = "internaldrive"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.disk-manager",
        displayName: "Disk Manager",
        description: "Inspect local disk capacity and usage.",
        order: 44
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                DiskManagerView()
            }
        ]
    }
}

private struct DiskManagerView: View {
    @LumiTheme private var theme
    @State private var snapshot: DiskSnapshot?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Disk Manager", systemImage: "internaldrive")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                        refresh()
                    }
                    .disabled(isLoading)
                }

                if let snapshot {
                    overview(snapshot)
                    usageCards(snapshot)
                } else if let errorMessage {
                    AppEmptyState(
                        icon: "exclamationmark.triangle",
                        title: "Disk Information Unavailable",
                        description: errorMessage,
                        actionTitle: "Refresh",
                        action: refresh
                    )
                    .frame(minHeight: 360)
                } else {
                    AppLoadingOverlay(message: "Loading Disk Information", size: .medium)
                        .frame(minHeight: 360)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(theme.appWindowBackground)
        .task {
            if snapshot == nil {
                refresh()
            }
        }
    }

    private func overview(_ snapshot: DiskSnapshot) -> some View {
        AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
            HStack(spacing: 20) {
                DiskUsageRing(usage: snapshot.usedRatio)
                    .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.volumeName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text("\(snapshot.formattedUsed) used of \(snapshot.formattedTotal)")
                        .font(.appBody)
                        .foregroundStyle(theme.textSecondary)

                    ProgressView(value: snapshot.usedRatio)
                        .tint(theme.primary)
                        .controlSize(.large)

                    Text("\(snapshot.formattedAvailable) available")
                        .font(.appCaption)
                        .foregroundStyle(theme.success)
                }

                Spacer()
            }
        }
    }

    private func usageCards(_ snapshot: DiskSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            metricCard("Total", value: snapshot.formattedTotal, icon: "externaldrive")
            metricCard("Used", value: snapshot.formattedUsed, icon: "chart.pie")
            metricCard("Available", value: snapshot.formattedAvailable, icon: "checkmark.circle")
            metricCard("Usage", value: snapshot.formattedPercent, icon: "percent")
        }
    }

    private func metricCard(_ title: String, value: String, icon: String) -> some View {
        AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(theme.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(theme.appAccentSoftFill))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    Text(value)
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                }

                Spacer()
            }
        }
    }

    private func refresh() {
        isLoading = true
        Task.detached {
            let result = Result { try DiskSnapshot.load() }
            await MainActor.run {
                switch result {
                case let .success(snapshot):
                    self.snapshot = snapshot
                    self.errorMessage = nil
                case let .failure(error):
                    self.snapshot = nil
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }
}

private struct DiskUsageRing: View {
    @LumiTheme private var theme
    let usage: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.appDivider, lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0, min(usage, 1)))
                .stroke(theme.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(usage, format: .percent.precision(.fractionLength(0)))
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
        }
    }
}

private struct DiskSnapshot: Sendable {
    let volumeName: String
    let total: Int64
    let used: Int64
    let available: Int64

    var usedRatio: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    var formattedTotal: String { Self.format(total) }
    var formattedUsed: String { Self.format(used) }
    var formattedAvailable: String { Self.format(available) }
    var formattedPercent: String { usedRatio.formatted(.percent.precision(.fractionLength(1))) }

    static func load() throws -> DiskSnapshot {
        let rootURL = URL(fileURLWithPath: "/")
        let values = try rootURL.resourceValues(forKeys: [.volumeNameKey])
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: rootURL.path)
        let total = attributes[.systemSize] as? Int64 ?? 0
        let available = attributes[.systemFreeSize] as? Int64 ?? 0
        return DiskSnapshot(
            volumeName: values.volumeName ?? "Macintosh HD",
            total: total,
            used: max(0, total - available),
            available: available
        )
    }

    private static func format(_ byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteCount)
    }
}
