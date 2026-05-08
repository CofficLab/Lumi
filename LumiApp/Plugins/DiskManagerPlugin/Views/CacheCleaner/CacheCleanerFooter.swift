import SwiftUI

/// 缓存清理底部操作栏
struct CacheCleanerFooter: View {
    @ObservedObject var viewModel: CacheCleanerViewModel
    @Binding var showCleanConfirmation: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("已选择：\(viewModel.formatBytes(viewModel.totalSelectedSize))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Text("\(viewModel.selection.count) 个项目")
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }

            Spacer()

            Button(action: {
                showCleanConfirmation = true
            }) {
                Label {
                    Text(viewModel.isCleaning ? "清理中..." : "立即清理")
                } icon: {
                    Image(systemName: "trash.fill")
                }
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "FF9F0A"))
            .disabled(viewModel.selection.isEmpty || viewModel.isCleaning)
        }
        .padding(.horizontal)
    }
}

#Preview {
    CacheCleanerFooter(viewModel: CacheCleanerViewModel(), showCleanConfirmation: .constant(false))
        .padding()
}
