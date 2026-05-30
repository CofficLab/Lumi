import SwiftUI
import LumiCoreKit
import LumiUI

/// LLM 可用性检测覆盖层
/// 在 RootView 出现时初始化可用性存储，并启动可用性检测
public struct AvailabilityOverlay<Content: View>: View {
    @EnvironmentObject private var llmVM: AppLLMVM

    public let content: Content

    @State private var hasInitialized = false

    public var body: some View {
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

        AvailabilityService.initializeIfNeeded(llmVM: llmVM)
    }
}

// MARK: - Preview

#Preview("Availability Overlay") {
    AvailabilityOverlay(content: Text("Content"))
        .inRootView()
}
