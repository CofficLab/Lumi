import LumiUI
import SwiftUI
import LumiKernel

public struct ProcessRow: View {
    public let process: NetworkProcess
    public let containerWidth: CGFloat

    public var body: some View {
        let horizontalPadding: CGFloat = 8
        let scrollBarWidth: CGFloat = 16
        // Calculate available width: Total - Left/Right Padding - Scrollbar
        let availableWidth = max(0, containerWidth - (horizontalPadding * 2) - scrollBarWidth)
        
        HStack(spacing: 0) {
            // Icon and Name
            HStack(spacing: 8) {
                if let icon = process.icon {
                    AppImageThumbnail(
                        image: Image(nsImage: icon),
                        size: CGSize(width: 24, height: 24),
                        shape: .none
                    )
                } else {
                    Image(systemName: "gearshape")
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                    Text(LumiPluginLocalization.string("PID: \(process.id)", bundle: .module))
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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

public struct SpeedText: View {
    public let speed: Double
    public let text: String

    // 阈值常量
    private let thresholdOrange: Double = 1 * 1024 * 1024 // 1 MB/s
    private let thresholdRed: Double = 5 * 1024 * 1024 // 5 MB/s

    public var color: Color {
        if speed >= thresholdRed {
            return Color(hex: "FF453A")
        } else if speed >= thresholdOrange {
            return Color(hex: "FF9F0A")
        } else {
            return Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
        }
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(color)
            .lineLimit(1)
            .truncationMode(.tail)
            // .fixedSize(horizontal: true, vertical: false)
    }
}
