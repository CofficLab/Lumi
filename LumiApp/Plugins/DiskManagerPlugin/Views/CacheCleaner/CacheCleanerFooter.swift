import SwiftUI

/// 缓存清理底部操作栏
struct CacheCleanerFooter: View {
    @ObservedObject var viewModel: CacheCleanerViewModel
    @Binding var showCleanConfirmation: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("已选择：\(viewModel.formatBytes(viewModel.totalSelectedSize))")
                    .font(.headline)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                Text("\(viewModel.selection.count) 个项目")
                    .font(.caption)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
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
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppUI.Color.semantic.warning)
            .disabled(viewModel.selection.isEmpty || viewModel.isCleaning)
        }
        .padding(.horizontal)
    }
}

#Preview {
    CacheCleanerFooter(viewModel: CacheCleanerViewModel(), showCleanConfirmation: .constant(false))
        .padding()
}
