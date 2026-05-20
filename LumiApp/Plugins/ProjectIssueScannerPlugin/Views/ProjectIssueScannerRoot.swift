import SwiftUI

/// 插件 Root 视图
///
/// 职责：
/// 1. 通过 @EnvironmentObject 捕获 AppLLMVM，将 LLM 服务传递给 DeepIssueAnalyzer。
/// 2. 监听空闲状态变化，在休息窗口内驱动 IdleScannerService。
struct ProjectIssueScannerRoot<Content: View>: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var idleTimeVM: AppIdleTimeVM
    @EnvironmentObject private var projectVM: WindowProjectVM

    let content: Content

    /// 防止在同一个休息窗口内重复触发
    @State private var hasTriggeredInCurrentWindow = false

    var body: some View {
        content
            .onAppear {
                configureLLMService()
            }
            .onChange(of: llmVM.currentModel) { _, _ in
                configureLLMService()
            }
            .onChange(of: idleTimeVM.isInRestWindow) { _, isInRest in
                if isInRest {
                    triggerScanIfNeeded()
                } else {
                    hasTriggeredInCurrentWindow = false
                }
            }
    }

    // MARK: - Private

    private func configureLLMService() {
        Task {
            await DeepIssueAnalyzer.shared.configure(
                llmService: llmVM.llmService,
                configProvider: llmVM
            )
        }
    }

    private func triggerScanIfNeeded() {
        guard !hasTriggeredInCurrentWindow else { return }
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }
        hasTriggeredInCurrentWindow = true

        Task {
            await IdleScannerService.shared.tryScan(
                idleDuration: 5 * 60, // 休息窗口意味着空闲足够长
                projectPath: path
            )
        }
    }
}
