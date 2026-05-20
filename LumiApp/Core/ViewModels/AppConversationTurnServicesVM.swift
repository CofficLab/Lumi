import Foundation
import SwiftUI

/// 供 UI 侧读取的最小服务集合：当前只保留 prompt/tool 能力。
///
/// ## 初始化规则
///
/// 由 `RootContainer` 持有并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var conversationTurnServices: AppConversationTurnServicesVM` 访问。
@MainActor
final class AppConversationTurnServicesVM: ObservableObject {
    let promptService: PromptService
    let toolService: ToolService

    init(promptService: PromptService, toolService: ToolService) {
        self.promptService = promptService
        self.toolService = toolService
    }
}

