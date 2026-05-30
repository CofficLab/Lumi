import SwiftUI
import LumiCoreKit

/// 工具输出渲染器
public struct ToolOutputRenderer: SuperMessageRenderer {
    public static let id = "tool-output"
    public static let priority = 180

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        message.role == .system && message.isToolOutput
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(ToolOutputView(message: message))
    }
}
