import Foundation
import Combine
import ProviderConversation
import ProviderMessage
import SwiftUI

/// 消息渲染器条目。
///
/// 复刻自旧版内核 KernelLumi 的 `LumiMessageRendererItem`：
/// - `canRender` 判定该消息是否由本渲染器处理；
/// - `render` 返回具体渲染视图（携带 `verbosity`，与旧版渲染器签名一致）。
@MainActor
public struct MessageRendererItem: Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let canRender: @Sendable (Message) -> Bool
    public let render: @MainActor @Sendable (Message, ResponseVerbosity) -> AnyView

    public init(
        id: String,
        order: Int = 0,
        canRender: @escaping @Sendable (Message) -> Bool = { _ in true },
        render: @escaping @MainActor @Sendable (Message, ResponseVerbosity) -> AnyView
    ) {
        self.id = id
        self.order = order
        self.canRender = canRender
        self.render = render
    }
}

@MainActor
public protocol MessageRenderingProviding: AnyObject, ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    var allRenderers: [MessageRendererItem] { get }
    func register(_ renderer: MessageRendererItem)
    func unregister(id: String)
    func renderer(for message: Message) -> MessageRendererItem?
}

@MainActor
public final class DefaultMessageRenderingProviding: MessageRenderingProviding, ObservableObject {
    @Published public private(set) var allRenderers: [MessageRendererItem] = []
    public init() {}
    public func register(_ renderer: MessageRendererItem) {
        allRenderers.removeAll { $0.id == renderer.id }
        allRenderers.append(renderer)
        allRenderers.sort { $0.order > $1.order }
    }
    public func unregister(id: String) {
        allRenderers.removeAll { $0.id == id }
    }
    public func renderer(for message: Message) -> MessageRendererItem? {
        if let preferredID = message.preferredRendererID,
           let preferred = allRenderers.first(where: { $0.id == preferredID && $0.canRender(message) }) {
            return preferred
        }
        return allRenderers.first { $0.canRender(message) }
    }
}
