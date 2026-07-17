import SwiftUI
import LumiCoreKit

/// 插件 Root 视图
///
/// 职责：提供插件根视图包装，并保持项目上下文可从 LumiCoreKit 注入。
public struct ProjectIssueScannerRoot<Content: View>: View {
    let lumiCore: LumiCoreAccessing
    public let content: Content

    /// 模型偏好（从 UserDefaults 加载）
    @State private var modelPreference: ScannerModelPreference = ScannerModelPreference.load()

    private var currentProjectPath: String {
        lumiCore.projectComponent.currentProject?.path ?? ""
    }

    public init(lumiCore: LumiCoreAccessing, @ViewBuilder content: () -> Content) {
        self.lumiCore = lumiCore
        self.content = content()
    }

    public var body: some View {
        content
            .sheet(isPresented: .constant(false)) {
                // 占位，实际使用 popover
            }
            .onChange(of: modelPreference) { _, newPreference in
                newPreference.save()
                let preference = newPreference
                Task {
                    await DeepIssueAnalyzer.shared.updateModelPreference(preference)
                }
            }
            .onAppear {
                let preference = modelPreference
                Task {
                    await DeepIssueAnalyzer.shared.updateModelPreference(preference)
                    await IdleScannerService.shared.tryScan(
                        idleDuration: 5 * 60,
                        projectPath: currentProjectPath
                    )
                }
            }
    }
}
