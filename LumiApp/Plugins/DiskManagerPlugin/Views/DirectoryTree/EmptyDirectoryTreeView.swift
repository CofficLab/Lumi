import SwiftUI

/// 目录树空状态视图（风格与大文件一致）
struct EmptyDirectoryTreeView: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel
    @State private var animate = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "7C6FFF").opacity(0.2), lineWidth: 10)
                    .frame(width: 88, height: 88)
                    .scaleEffect(animate ? 1.06 : 0.96)
                    .opacity(animate ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

                Image(systemName: "folder")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color(hex: "7C6FFF"))
            }

            VStack(spacing: 10) {
                Text("暂无目录数据")
                    .font(.title3)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Text("点击开始分析，查看目录占用与结构。")
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                Button(action: { viewModel.startScan() }, label: {
                    Label(title: { Text("开始分析") }, icon: { Image(systemName: "folder.badge.gear") })
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                })
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "7C6FFF"))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "7C6FFF").opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "7C6FFF").opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

#Preview {
    EmptyDirectoryTreeView(viewModel: DirectoryTreeViewModel())
        .padding()
}

