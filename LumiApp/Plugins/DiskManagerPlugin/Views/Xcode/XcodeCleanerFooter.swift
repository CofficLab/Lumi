import SwiftUI
import AppKit

/// Xcode 清理底部操作栏
struct XcodeCleanerFooter: View {
    @ObservedObject var viewModel: XcodeCleanerViewModel
    @Binding var showCleanConfirmation: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("已选择：\(viewModel.formatBytes(viewModel.selectedSize))")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text("总计：\(viewModel.formatBytes(viewModel.totalSize))")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()

            if let error = viewModel.errorMessage {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(error)
                        .foregroundColor(DesignTokens.Color.semantic.error)
                        .font(.caption)
                        .multilineTextAlignment(.trailing)
                    if viewModel.isPermissionError {
                        Button(action: openFullDiskAccessSettings) {
                            Text("打开系统设置")
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }

            Button(action: {
                showCleanConfirmation = true
            }, label: {
                Label(title: { Text(viewModel.isCleaning ? "清理中..." : "立即清理") }, icon: {
                    Image(systemName: "trash.fill")
                })
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Color.semantic.warning)
            .disabled(viewModel.selectedSize == 0 || viewModel.isCleaning)
        }
        .padding(.horizontal)
    }

    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    XcodeCleanerFooter(viewModel: XcodeCleanerViewModel(), showCleanConfirmation: .constant(false))
        .padding()
}
