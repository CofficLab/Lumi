import Foundation
import ProviderToolbar

/// 空态工具栏控制所需的最小工具栏能力。
@MainActor
public protocol MessageListToolbarCapability: AnyObject {
    func setHiddenCategories(_ categories: Set<ToolbarItemCategory>, for source: String)
}

@MainActor
public final class MessageListToolbarCapabilityAdapter: MessageListToolbarCapability {
    private let toolbar: any ToolbarProviding
    public init(toolbar: any ToolbarProviding) { self.toolbar = toolbar }
    public func setHiddenCategories(_ categories: Set<ToolbarItemCategory>, for source: String) {
        toolbar.setHiddenCategories(categories, for: source)
    }
}