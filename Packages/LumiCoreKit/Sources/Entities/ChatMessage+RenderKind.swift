import Foundation

public extension ChatMessage {
    /// 是否带有指定前缀的 renderKind（用于供应商自定义渲染器匹配）。
    func hasRenderKind(withPrefix prefix: String) -> Bool {
        renderKind?.hasPrefix(prefix) == true
    }
}
