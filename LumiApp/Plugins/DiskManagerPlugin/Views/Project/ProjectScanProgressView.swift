import SwiftUI

/// 项目清理扫描进度视图
struct ProjectScanProgressView: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel
    @State private var animate = false

    var body: some View {
        let current = viewModel.scanProgress.isEmpty ? "用户主目录" : viewModel.scanProgress
        let totalSize = viewModel.projects.reduce(0 as Int64) { $0 + $1.totalSize }

        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(DesignTokens.Color.semantic.warning.opacity(0.2), lineWidth: 10)
                    .frame(width: 88, height: 88)
                    .scaleEffect(animate ? 1.06 : 0.96)
                    .opacity(animate ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        DesignTokens.Color.semantic.warning,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: animate)

                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.warning)
            }

            VStack(spacing: 6) {
                Text("正在扫描项目")
                    .font(.title3)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(current)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 16) {
                    Label {
                        Text("\(viewModel.projects.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.primary)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }

                    Label {
                        Text(viewModel.formatBytes(totalSize))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.warning)
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
                .fill(DesignTokens.Color.semantic.warning.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignTokens.Color.semantic.warning.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

#Preview {
    ProjectScanProgressView(viewModel: ProjectCleanerViewModel())
        .padding()
}
