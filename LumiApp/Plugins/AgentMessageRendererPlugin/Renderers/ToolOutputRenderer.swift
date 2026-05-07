import SwiftUI

/// 工具输出渲染器
struct ToolOutputRenderer: SuperMessageRenderer {
    static let id = "tool-output"
    static let priority = 180

    func canRender(message: ChatMessage) -> Bool {
        message.role == .system && message.isToolOutput
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(ToolOutputView(message: message))
    }
}
