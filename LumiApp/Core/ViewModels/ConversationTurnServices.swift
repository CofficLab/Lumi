import Foundation
import SwiftUI

/// 供 UI 侧读取的最小服务集合：当前只保留 prompt/tool 能力。
@MainActor
final class ConversationTurnServices: ObservableObject {
    let promptService: PromptService
    let toolService: ToolService

    init(promptService: PromptService, toolService: ToolService) {
        self.promptService = promptService
        self.toolService = toolService
    }
}

