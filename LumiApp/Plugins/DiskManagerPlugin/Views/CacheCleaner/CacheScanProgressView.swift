import SwiftUI

/// 缓存清理扫描进度视图
struct CacheScanProgressView: View {
    @ObservedObject var viewModel: CacheCleanerViewModel
    @State private var animate = false

    var body: some View {
        VStack(spacing: 12) {
            // 扫描图标和动画
            ZStack {
                // 外圈光晕
                Circle()
                    .stroke(
                        AppUI.Color.semantic.warning.opacity(0.2),
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
                        AppUI.Color.semantic.warning,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: animate)

                // 中心图标
                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.warning)
            }

            // 进度信息
            VStack(spacing: 6) {
                Text("正在扫描系统缓存")
                    .font(.title3)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.gear")
                        .font(.caption)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    Text(viewModel.scanProgress.isEmpty ? "用户主目录" : viewModel.scanProgress)
                        .font(.caption)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 16) {
                    Label {
                        Text("\(viewModel.categories.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppUI.Color.semantic.primary)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }

                    Label {
                        Text("分类")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppUI.Color.semantic.warning)
                    } icon: {
                        Image(systemName: "doc.badge.clock")
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppUI.Color.semantic.warning.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppUI.Color.semantic.warning.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

#Preview {
    CacheScanProgressView(viewModel: CacheCleanerViewModel())
        .padding()
}
