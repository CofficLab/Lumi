import SwiftUI

struct ProcessRow: View {
    let process: NetworkProcess
    let containerWidth: CGFloat

    var body: some View {
        let horizontalPadding: CGFloat = 8
        let scrollBarWidth: CGFloat = 16
        // Calculate available width: Total - Left/Right Padding - Scrollbar
        let availableWidth = max(0, containerWidth - (horizontalPadding * 2) - scrollBarWidth)
        
        HStack(spacing: 0) {
            // Icon and Name
            HStack(spacing: 8) {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "gearshape")
                        .frame(width: 24, height: 24)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text(String(localized: "PID: \(process.id)", table: "NetworkManager"))
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
            .frame(width: availableWidth * 0.50, alignment: .leading)

            Spacer()

            // Speed columns
            SpeedText(speed: process.downloadSpeed, text: process.formattedDownload)
                .frame(width: availableWidth * 0.25, alignment: .trailing)

            SpeedText(speed: process.uploadSpeed, text: process.formattedUpload)
                .frame(width: availableWidth * 0.25, alignment: .trailing)
        }
        .padding(.horizontal, horizontalPadding)
        // Note: List rows usually don't need manual scrollBarWidth padding,
        // because content automatically avoids scrollbar or it overlays.
        // But to align with header, we use availableWidth and trailing padding.
        .padding(.trailing, scrollBarWidth) // Ensure text doesn't hit scrollbar and aligns with header
        .padding(.vertical, 4)
    }
}

struct SpeedText: View {
    let speed: Double
    let text: String

    // 阈值常量
    private let thresholdOrange: Double = 1 * 1024 * 1024 // 1 MB/s
    private let thresholdRed: Double = 5 * 1024 * 1024 // 5 MB/s

    var color: Color {
        if speed >= thresholdRed {
            return DesignTokens.Color.semantic.error
        } else if speed >= thresholdOrange {
            return DesignTokens.Color.semantic.warning
        } else {
            return DesignTokens.Color.semantic.textPrimary
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(color)
            .lineLimit(1)
            .truncationMode(.tail)
            // .fixedSize(horizontal: true, vertical: false)
    }
}
