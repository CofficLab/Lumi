import MagicKit
import SwiftUI
import os

/// LLM 可用性检测覆盖层
/// 在 RootView 出现时初始化可用性存储，并启动可用性检测
struct LLMAvailabilityOverlay<Content: View>: View {
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

extension LLMAvailabilityOverlay {
    private func handleOnAppear() async {
        guard !hasInitialized else { return }
        hasInitialized = true

        if LLMAvailabilityPlugin.verbose {
            if LLMAvailabilityPlugin.verbose {
                            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)🚀 初始化 LLM 可用性检测覆盖层")
            }
        }

        // 初始化可用性列表（从当前 AppLLMVM 获取所有供应商+模型）
        // .task modifier 本身已在 @MainActor 上执行，无需额外调度
        let store = LLMAvailabilityStore.shared
        store.initialize(from: llmVM)

        // 启动可用性检测（在后台任务中执行）
        // llmService 从 llmVM 中获取
        let checker = LLMAvailabilityChecker(llmService: llmVM.llmService)
        Task.detached {
            await checker.checkAll()
        }
    }
}

// MARK: - Preview

#Preview("LLM Availability Overlay") {
    LLMAvailabilityOverlay(content: Text("Content"))
        .inRootView()
}
