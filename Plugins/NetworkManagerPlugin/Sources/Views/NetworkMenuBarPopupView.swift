import LumiUI
import SwiftUI
import LumiKernel

/// Menu bar popup view for Network Manager plugin
public struct NetworkMenuBarPopupView: View {
    // MARK: - Properties

    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject private var viewModel = NetworkManagerViewModel.shared
    @ObservedObject private var historyService = NetworkHistoryService.shared

    // MARK: - Body

    public var body: some View {
        HoverableContainerView(detailView: NetworkHistoryDetailView()) {
            VStack(spacing: 0) {
                // Real-time speed display
                liveSpeedView

                // History trend chart (last 60 seconds)
                miniTrendView
            }
        }
    }

    // MARK: - Live Speed View

    private var liveSpeedView: some View {
        HStack(spacing: 16) {
            // Download speed
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.appMicro)
                    .foregroundColor(theme.success)

                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.downloadSpeed))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .frame(alignment: .leading)
            }
            .frame(width: 100, alignment: .leading)

            Spacer()

            GlassDivider()
                .frame(height: 24)

            Spacer()

            // Upload speed
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.appMicro)
                    .foregroundColor(theme.error)

                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.uploadSpeed))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .frame(alignment: .leading)
            }
            .frame(width: 100, alignment: .leading)
        }
        .padding(10)
    }

    // MARK: - Mini Trend View

    private var miniTrendView: some View {
        let recentData = Array(historyService.recentHistory.suffix(60))
        let maxSpeed = max(
            recentData.map(\.downloadSpeed).max() ?? 0,
            recentData.map(\.uploadSpeed).max() ?? 0,
            1024 // Minimum scale
        )

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)

                Text(LumiPluginLocalization.string("Last 60 seconds", bundle: .module))
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)

                Spacer()

                // Legend
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(theme.success.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(LumiPluginLocalization.string("Down", bundle: .module))
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }

                    HStack(spacing: 3) {
                        Circle()
                            .fill(theme.error.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(LumiPluginLocalization.string("Up", bundle: .module))
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)

            // Mini chart
            GeometryReader { geometry in
                ZStack {
                    // Background grid lines
                    ForEach(0 ..< 3) { i in
                        let y = CGFloat(i) * geometry.size.height / 2
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(theme.textTertiary.opacity(0.1), lineWidth: 1)
                    }

                    // Download area
                    if !recentData.isEmpty {
                        MiniGraphArea(
                            data: recentData.map(\.downloadSpeed),
                            maxValue: maxSpeed
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.success.opacity(0.4),
                                    theme.success.opacity(0.05),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Download line
                        MiniGraphLine(
                            data: recentData.map(\.downloadSpeed),
                            maxValue: maxSpeed
                        )
                        .stroke(theme.success.opacity(0.8), lineWidth: 1.2)

                        // Upload area
                        MiniGraphArea(
                            data: recentData.map(\.uploadSpeed),
                            maxValue: maxSpeed
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.error.opacity(0.4),
                                    theme.error.opacity(0.05),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Upload line
                        MiniGraphLine(
                            data: recentData.map(\.uploadSpeed),
                            maxValue: maxSpeed
                        )
                        .stroke(theme.error.opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text(LumiPluginLocalization.string("Collecting...", bundle: .module))
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .appSurface(style: .subtle)
    }
}

// MARK: - Process Row View

public struct ProcessRowView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let process: NetworkProcess

    public var body: some View {
        HStack(spacing: 8) {
            // Process icon
            if let icon = process.icon {
                AppImageThumbnail(
                    image: Image(nsImage: icon),
                    size: CGSize(width: 16, height: 16),
                    shape: .none
                )
            } else {
                Image(systemName: "app")
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            }

            // Process name
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.appCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Text(LumiPluginLocalization.string("PID: \(process.id)", bundle: .module))
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            Spacer()

            // Speed
            HStack(spacing: 4) {
                // Download
                if process.downloadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.appMicro)
                            .foregroundColor(theme.success)

                        Text(SpeedFormatter.formatForStatusBar(process.downloadSpeed))
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                // Upload
                if process.uploadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.appMicro)
                            .foregroundColor(theme.error)

                        Text(SpeedFormatter.formatForStatusBar(process.uploadSpeed))
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview("Network Status Bar Popup") {
    NetworkMenuBarPopupView()
        .frame(width: 400)
        .frame(height: 400)
}
