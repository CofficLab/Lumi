import LumiUI
import SwiftUI

/// 空大文件列表视图
struct EmptyLargeFilesView: View {
    @ObservedObject var viewModel: LargeFilesViewModel
    @State private var animate = false

    init(viewModel: LargeFilesViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "0A84FF").opacity(0.2), lineWidth: 10)
                    .frame(width: 88, height: 88)
                    .scaleEffect(animate ? 1.06 : 0.96)
                    .opacity(animate ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color(hex: "0A84FF"))
            }

            VStack(spacing: 10) {
                Text(PluginDiskManagerLocalization.string("暂无大文件"))
                    .font(.title3)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Text(PluginDiskManagerLocalization.string("你可以扫描用户主目录，找到占用空间较大的文件。"))
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                AppButton(
                    PluginDiskManagerLocalization.string("开始扫描"),
                    systemImage: "magnifyingglass.circle",
                    style: .primary,
                    action: { viewModel.startScan() }
                )
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
