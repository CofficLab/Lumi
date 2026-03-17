import SwiftUI

/// 大文件扫描进度视图
struct LargeFilesScanProgressView: View {
    @ObservedObject var viewModel: LargeFilesViewModel
    @State private var animate = false

    var body: some View {
        let scannedFiles = viewModel.scanProgress?.scannedFiles ?? 0
        let scannedDirectories = viewModel.scanProgress?.scannedDirectories ?? 0
        let scannedTotal = scannedFiles + scannedDirectories
        let scannedBytes = viewModel.scanProgress?.scannedBytes ?? 0
        let currentPath = viewModel.scanProgress?.currentPath ?? FileManager.default.homeDirectoryForCurrentUser.path

        VStack(spacing: 12) {
            // 扫描图标和动画
            ZStack {
                // 外圈光晕
                Circle()
                    .stroke(
                        DesignTokens.Color.semantic.info.opacity(0.2),
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
                        DesignTokens.Color.semantic.info,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: animate)

                // 中心图标
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.info)
            }

            // 进度信息
            VStack(spacing: 6) {
                Text("正在扫描大文件")
                    .font(.title3)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(URL(fileURLWithPath: currentPath).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 16) {
                    Label {
                        Text("\(scannedTotal)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.primary)
                    } icon: {
                        Image(systemName: "doc.fill")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }

                    Label {
                        Text(viewModel.formatBytes(Int64(scannedBytes)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.info)
                    } icon: {
                        Image(systemName: "internaldrive.fill")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.Color.semantic.info.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignTokens.Color.semantic.info.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

#Preview {
    LargeFilesScanProgressView(viewModel: LargeFilesViewModel())
        .padding()
}
