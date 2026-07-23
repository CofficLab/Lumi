import Foundation
import LumiKernel

/// 消息渲染器管理器
///
/// 负责管理所有已注册的消息渲染器，提供渲染器查询接口。
/// 插件通过 LumiPlugin.messageRenderers(kernel:) 贡献渲染器，
/// 由本服务统一注册和管理。
@MainActor
public final class MessageRendererManager: MessageRendererManaging {
    public static let shared = MessageRendererManager()

    // MARK: - State

    private var messageRenderers: [String: LumiMessageRendererItem] = [:]
    private var messageRendererOrder: [String] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - MessageRendererManaging

    public func allMessageRenderers() -> [LumiMessageRendererItem] {
        messageRendererOrder.compactMap { messageRenderers[$0] }
    }

    public func registerMessageRenderer(_ renderer: LumiMessageRendererItem) {
        if messageRenderers[renderer.id] == nil {
            messageRendererOrder.append(renderer.id)
        }
        messageRenderers[renderer.id] = renderer
    }

    public func unregisterMessageRenderer(id: String) {
        messageRenderers.removeValue(forKey: id)
        messageRendererOrder.removeAll { $0 == id }
    }

    public func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? {
        allMessageRenderers()
            .sorted { $0.order > $1.order }
            .first { $0.canRender(message) }
    }
}
