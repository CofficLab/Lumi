import SwiftUI

/// 空项目列表视图
struct EmptyProjectView: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel
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

                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.warning)
            }

            VStack(spacing: 10) {
                Text("未发现可清理的项目")
                    .font(.title3)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Text("已扫描：Code、Projects、Developer 等目录")
                    .font(.caption)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                Button(action: { Task { await viewModel.scanProjects() } }, label: {
                    Label(title: { Text("重新扫描") }, icon: { Image(systemName: "arrow.clockwise") })
                        .font(.headline)
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
    EmptyProjectView(viewModel: ProjectCleanerViewModel())
        .padding()
}
