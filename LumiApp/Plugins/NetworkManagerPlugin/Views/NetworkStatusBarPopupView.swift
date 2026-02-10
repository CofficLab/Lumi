import MagicKit
import SwiftUI

/// Status bar popup view for Network Manager plugin
struct NetworkStatusBarPopupView: View {
    // MARK: - Properties

    @StateObject private var viewModel = NetworkManagerViewModel()
    @ObservedObject private var historyService = NetworkHistoryService.shared

    // MARK: - Body

    var body: some View {
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
                    .font(.system(size: 12))
                    .foregroundColor(.green)

                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.downloadSpeed))
                    .font(.system(size: 14, weight: .medium))
                    .frame(alignment: .leading)
            }
            .frame(width: 100, alignment: .leading)

            Spacer()

            Divider()
                .frame(height: 24)

            Spacer()

            // Upload speed
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)

                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.uploadSpeed))
                    .font(.system(size: 14, weight: .medium))
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
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("Last 60 seconds")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                // Legend
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text("Down")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.red.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text("Up")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
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
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
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
                                    Color.green.opacity(0.4),
                                    Color.green.opacity(0.05),
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
                        .stroke(Color.green.opacity(0.8), lineWidth: 1.2)

                        // Upload area
                        MiniGraphArea(
                            data: recentData.map(\.uploadSpeed),
                            maxValue: maxSpeed
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.red.opacity(0.4),
                                    Color.red.opacity(0.05),
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
                        .stroke(Color.red.opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text("Collecting...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(.background.opacity(0.3))
    }
}

// MARK: - Process Row View

struct ProcessRowView: View {
    let process: NetworkProcess

    var body: some View {
        HStack(spacing: 8) {
            // Process icon
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Process name
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Text("PID: \(process.id)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Speed
            HStack(spacing: 4) {
                // Download
                if process.downloadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)

                        Text(SpeedFormatter.formatForStatusBar(process.downloadSpeed))
                            .font(.system(size: 10))
                    }
                }

                // Upload
                if process.uploadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.red)

                        Text(SpeedFormatter.formatForStatusBar(process.uploadSpeed))
                            .font(.system(size: 10))
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
    NetworkStatusBarPopupView()
        .frame(width: 400)
        .frame(height: 400)
}
