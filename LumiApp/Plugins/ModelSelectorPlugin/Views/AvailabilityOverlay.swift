import SwiftUI

/// LLM 可用性检测覆盖层
/// 在 RootView 出现时初始化可用性存储，并启动可用性检测
struct AvailabilityOverlay<Content: View>: View {
    @EnvironmentObject private var llmVM: AppLLMVM

    let content: Content

    @State private var hasInitialized = false

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await handleOnAppear()
        }
    }
}

// MARK: - Event Handler

extension AvailabilityOverlay {
    private func handleOnAppear() async {
        guard !hasInitialized else { return }
        hasInitialized = true

        if LLMAvailabilityPlugin.verbose {
            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)🚀 初始化 LLM 可用性检测覆盖层")
        }

        AvailabilityService.initializeIfNeeded(llmVM: llmVM)
    }
}

// MARK: - Preview

#Preview("Availability Overlay") {
    AvailabilityOverlay(content: Text("Content"))
        .inRootView()
}
