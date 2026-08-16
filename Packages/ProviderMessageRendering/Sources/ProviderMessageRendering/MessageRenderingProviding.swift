import Foundation
import ProviderMessage

public struct MessageRendererItem: Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let canRender: @Sendable (Message) -> Bool
    public init(id: String, order: Int = 0, canRender: @escaping @Sendable (Message) -> Bool = { _ in true }) { self.id = id; self.order = order; self.canRender = canRender }
}
@MainActor
public protocol MessageRenderingProviding: AnyObject {
    var allRenderers: [MessageRendererItem] { get }
    func register(_ renderer: MessageRendererItem)
    func unregister(id: String)
    func renderer(for message: Message) -> MessageRendererItem?
}
@MainActor
public final class DefaultMessageRenderingProviding: MessageRenderingProviding {
    public private(set) var allRenderers: [MessageRendererItem] = []
    public init() {}
    public func register(_ renderer: MessageRendererItem) { allRenderers.removeAll { $0.id == renderer.id }; allRenderers.append(renderer); allRenderers.sort { $0.order > $1.order } }
    public func unregister(id: String) { allRenderers.removeAll { $0.id == id } }
    public func renderer(for message: Message) -> MessageRendererItem? { allRenderers.first { $0.canRender(message) } }
}
