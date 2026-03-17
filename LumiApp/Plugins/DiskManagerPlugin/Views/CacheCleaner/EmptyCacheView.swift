import SwiftUI

/// 空缓存列表视图
struct EmptyCacheView: View {
    @ObservedObject var viewModel: CacheCleanerViewModel

    var body: some View {
        ContentUnavailableView {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Color.semantic.warning.opacity(0.6))
                .padding(.bottom, 8)
        } description: {
            VStack(spacing: 12) {
                Text("准备就绪")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text("点击扫描按钮开始分析系统缓存")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                Button(action: {
                    viewModel.scan()
                }, label: {
                    Label(title: { Text("开始扫描") }, icon: {
                        Image(systemName: "magnifyingglass.circle")
                    })
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                })
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Color.semantic.info)
            }
        }
    }
}

#Preview {
    EmptyCacheView(viewModel: CacheCleanerViewModel())
        .padding()
}
