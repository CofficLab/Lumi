import LumiUI
import SwiftUI

/// 空缓存列表视图
struct EmptyCacheView: View {
    @ObservedObject var viewModel: CacheCleanerViewModel
    @State private var animate = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "FF9F0A").opacity(0.2), lineWidth: 10)
                    .frame(width: 88, height: 88)
                    .scaleEffect(animate ? 1.06 : 0.96)
                    .opacity(animate ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color(hex: "FF9F0A"))
            }

            VStack(spacing: 10) {
                Text(PluginDiskManagerLocalization.string("准备就绪"))
                    .font(.title3)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Text(PluginDiskManagerLocalization.string("点击开始扫描，分析系统缓存并可一键清理。"))
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                AppButton(
                    PluginDiskManagerLocalization.string("开始扫描"),
                    systemImage: "doc.badge.gearshape",
                    style: .primary,
                    action: { viewModel.scan() }
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "FF9F0A").opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "FF9F0A").opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}
