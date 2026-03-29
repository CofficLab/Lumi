import SwiftUI

/// 项目清理底部操作栏
struct ProjectCleanerFooter: View {
    @ObservedObject var viewModel: ProjectCleanerViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("已选择清理")
                    .font(.caption)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                Text(viewModel.formatBytes(viewModel.totalSelectedSize))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
            }

            Spacer()

            Button(action: {
                viewModel.showCleanConfirmation = true
            }, label: {
                Label(title: { Text(viewModel.isCleaning ? "清理中..." : "立即清理") }, icon: {
                    Image(systemName: "trash.fill")
                })
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(AppUI.Color.semantic.warning)
            .disabled(viewModel.selectedItemIds.isEmpty || viewModel.isCleaning || viewModel.isScanning)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ProjectCleanerFooter(viewModel: ProjectCleanerViewModel())
        .padding()
}
