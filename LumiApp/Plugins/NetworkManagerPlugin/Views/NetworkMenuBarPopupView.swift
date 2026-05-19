import LumiUI
import MagicKit
import SwiftUI

/// Menu bar popup view for Network Manager plugin
struct NetworkMenuBarPopupView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel = NetworkManagerViewModel.shared
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
                    .foregroundColor(Color(hex: "30D158"))

                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.downloadSpeed))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
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
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "FF453A"))

                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.uploadSpeed))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
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
                    .foregroundColor(Color(hex: "98989E"))

                Text(String(localized: "Last 60 seconds"))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))

                Spacer()

                // Legend
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(hex: "30D158").opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(String(localized: "Down"))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "98989E"))
                    }

                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(hex: "FF453A").opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(String(localized: "Up"))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "98989E"))
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
                        .stroke(Color(hex: "98989E").opacity(0.1), lineWidth: 1)
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
                                    Color(hex: "30D158").opacity(0.4),
                                    Color(hex: "30D158").opacity(0.05),
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
                        .stroke(Color(hex: "30D158").opacity(0.8), lineWidth: 1.2)

                        // Upload area
                        MiniGraphArea(
                            data: recentData.map(\.uploadSpeed),
                            maxValue: maxSpeed
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "FF453A").opacity(0.4),
                                    Color(hex: "FF453A").opacity(0.05),
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
                        .stroke(Color(hex: "FF453A").opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text(String(localized: "Collecting..."))
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "98989E"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
    }
}

// MARK: - Process Row View

struct ProcessRowView: View {
    let process: NetworkProcess

    var body: some View {
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
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "98989E"))
            }

            // Process name
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 11))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .lineLimit(1)

                Text(String(localized: "PID: \(process.id)"))
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "98989E"))
            }

            Spacer()

            // Speed
            HStack(spacing: 4) {
                // Download
                if process.downloadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "30D158"))

                        Text(SpeedFormatter.formatForStatusBar(process.downloadSpeed))
                            .font(.system(size: 10))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                }

                // Upload
                if process.uploadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "FF453A"))

                        Text(SpeedFormatter.formatForStatusBar(process.uploadSpeed))
                            .font(.system(size: 10))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
