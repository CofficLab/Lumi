import SwiftUI

struct ProcessRow: View {
    let process: NetworkProcess
    let containerWidth: CGFloat

    var body: some View {
        let horizontalPadding: CGFloat = 8
        let scrollBarWidth: CGFloat = 16
        // 计算可用宽度：总宽度 - 左右Padding - 滚动条预留
        let availableWidth = max(0, containerWidth - (horizontalPadding * 2) - scrollBarWidth)
        
        HStack(spacing: 0) {
            // 图标与名称
            HStack(spacing: 8) {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "gearshape")
                        .frame(width: 24, height: 24)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    Text("PID: \(process.id)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: availableWidth * 0.50, alignment: .leading)

            Spacer()

            // 速度列
            SpeedText(speed: process.downloadSpeed, text: process.formattedDownload)
                .frame(width: availableWidth * 0.25, alignment: .trailing)

            SpeedText(speed: process.uploadSpeed, text: process.formattedUpload)
                .frame(width: availableWidth * 0.25, alignment: .trailing)
        }
        .padding(.horizontal, horizontalPadding)
        // 注意：列表行通常不需要手动添加 scrollBarWidth 的 padding，
        // 因为内容会自动避开滚动条，或者滚动条覆盖在内容之上。
        // 但为了防止内容被覆盖，且与表头对齐，这里不加额外的 padding，而是依靠 availableWidth 的缩减来限制内容宽度。
        // 关键点：HStack 默认居中。我们需要它靠左吗？不，padding horizontal 保证了位置。
        // 如果 availableWidth 变小了，Spacer 会吸收多余空间。
        // 为了确保右对齐的文字不贴边，我们需要让 HStack 填满 containerWidth - scrollBarWidth 吗？
        // 不，最好的办法是给 HStack 一个明确的 frame，或者加 trailing padding。
        .padding(.trailing, scrollBarWidth) // 加上这个以确保文字不会被滚动条遮挡，并与表头对齐
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
            return .red
        } else if speed >= thresholdOrange {
            return .orange
        } else {
            return .primary
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
