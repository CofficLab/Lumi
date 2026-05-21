import LumiUI
import SwiftUI

/// 空项目列表视图
struct EmptyProjectView: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel
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

                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color(hex: "FF9F0A"))
            }

            VStack(spacing: 10) {
                Text(String(localized: "未发现可清理的项目", table: "DiskManager"))
                    .font(.title3)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Text(String(localized: "已扫描：Code、Projects、Developer 等目录", table: "DiskManager"))
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                AppButton(
                    localized: "重新扫描",
                    table: "DiskManager",
                    systemImage: "arrow.clockwise",
                    style: .primary,
                    action: { Task { await viewModel.scanProjects() } }
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

#Preview {
    EmptyProjectView(viewModel: ProjectCleanerViewModel())
        .padding()
}
