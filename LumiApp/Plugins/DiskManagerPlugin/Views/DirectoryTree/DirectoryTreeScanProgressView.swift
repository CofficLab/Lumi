import SwiftUI

/// 目录树扫描进度视图
struct DirectoryTreeScanProgressView: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel
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
                        AppUI.Color.semantic.primary.opacity(0.2),
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
                        AppUI.Color.semantic.primary,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: animate)

                // 中心图标
                Image(systemName: "folder.badge.gear")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.primary)
            }

            // 进度信息
            VStack(spacing: 6) {
                Text("正在分析目录结构")
                    .font(.title3)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    Text(URL(fileURLWithPath: currentPath).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
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
                            .foregroundColor(AppUI.Color.semantic.primary)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }

                    Label {
                        Text(viewModel.formatBytes(Int64(scannedBytes)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppUI.Color.semantic.info)
                    } icon: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppUI.Color.semantic.primary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppUI.Color.semantic.primary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

#Preview {
    DirectoryTreeScanProgressView(viewModel: DirectoryTreeViewModel())
        .padding()
}
