import SwiftUI

/// Xcode 清理扫描进度视图
struct XcodeScanProgressView: View {
    @ObservedObject var viewModel: XcodeCleanerViewModel
    @State private var animate = false

    var body: some View {
        let current = viewModel.scanProgress.isEmpty ? "开发者缓存目录" : viewModel.scanProgress
        let totalCount = viewModel.itemsByCategory.values.flatMap { $0 }.count

        VStack(spacing: 12) {
            // 扫描图标和动画
            ZStack {
                // 外圈光晕
                Circle()
                    .stroke(
                        Color(hex: "0A84FF").opacity(0.2),
                        lineWidth: 10
                    )
                    .frame(width: 88, height: 88)
                    .scaleEffect(animate ? 1.06 : 0.96)
                    .opacity(animate ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

                // 旋转的扫描线
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        Color(hex: "0A84FF"),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: animate)

                // 中心图标
                Image(systemName: "hammer")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color(hex: "0A84FF"))
            }

            // 进度信息
            VStack(spacing: 6) {
                Text(PluginDiskManagerLocalization.string("正在扫描 Xcode 缓存"))
                    .font(.title3)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.gear")
                        .font(.caption)
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    Text(current)
                        .font(.caption)
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 16) {
                    Label {
                        Text("\(totalCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "7C6FFF"))
                    } icon: {
                        Image(systemName: "doc.fill")
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }

                    Label {
                        Text(viewModel.formatBytes(viewModel.totalSize))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "0A84FF"))
                    } icon: {
                        Image(systemName: "internaldrive.fill")
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "0A84FF").opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "0A84FF").opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

