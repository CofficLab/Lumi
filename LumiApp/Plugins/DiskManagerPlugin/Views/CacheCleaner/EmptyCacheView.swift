import SwiftUI

/// 空缓存列表视图
struct EmptyCacheView: View {
    @ObservedObject var viewModel: CacheCleanerViewModel
    @State private var animate = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(AppUI.Color.semantic.warning.opacity(0.2), lineWidth: 10)
                    .frame(width: 88, height: 88)
                    .scaleEffect(animate ? 1.06 : 0.96)
                    .opacity(animate ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.warning)
            }

            VStack(spacing: 10) {
                Text("准备就绪")
                    .font(.title3)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Text("点击开始扫描，分析系统缓存并可一键清理。")
                    .font(.caption)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                Button(action: { viewModel.scan() }, label: {
                    Label(title: { Text("开始扫描") }, icon: { Image(systemName: "doc.badge.gearshape") })
                        .font(AppUI.Typography.bodyEmphasized)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                })
                .buttonStyle(.borderedProminent)
                .tint(AppUI.Color.semantic.warning)
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
    EmptyCacheView(viewModel: CacheCleanerViewModel())
        .padding()
}
