import MagicKit
import SwiftUI

/// LLM 可用性检测覆盖层
/// 在 RootView 出现时初始化可用性存储，并启动可用性检测
struct LLMAvailabilityOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool = false
    nonisolated static var emoji: String { "🔍" }

    @EnvironmentObject private var container: RootViewContainer
    @EnvironmentObject private var llmVM: LLMVM

    let content: Content

    @StateObject private var store = LLMAvailabilityStore.shared

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            handleOnAppear()
        }
        .environmentObject(store)
    }
}

// MARK: - Event Handler

extension LLMAvailabilityOverlay {
    private func handleOnAppear() {
        // 初始化可用性列表（从当前 LLMVM 获取所有供应商+模型）
        store.initialize(from: llmVM)

        // 启动可用性检测（在后台任务中执行）
        let checker = LLMAvailabilityChecker(llmService: container.llmService)
        Task {
            await checker.checkAll()
        }
    }
}

// MARK: - Preview

#Preview("LLM Availability Overlay") {
    LLMAvailabilityOverlay(content: Text("Content"))
        .inRootView()
}
