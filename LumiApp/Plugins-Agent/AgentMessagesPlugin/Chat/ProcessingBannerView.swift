import SwiftUI

/// 顶部处理状态提示条
///
/// 基于 `ProcessingStateVM` 展示当前对话的处理阶段文案。
struct ProcessingBannerView: View {
    @EnvironmentObject private var processingStateViewModel: ProcessingStateVM

    var body: some View {
        if processingStateViewModel.hasActiveLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text(processingStateViewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
            )
            .padding(.horizontal)
            .padding(.top, 4)
        }
    }
}

#Preview {
    ProcessingBannerView()
        .environmentObject(ProcessingStateVM())
        .frame(width: 400)
        .padding()
}

