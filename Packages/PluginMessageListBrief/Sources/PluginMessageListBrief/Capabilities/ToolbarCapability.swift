import ProviderToolbar
import ProviderToolManager

/// 空态工具栏控制所需的最小工具栏能力。
@MainActor
protocol MessageListToolbarCapability: AnyObject {
    func setHiddenCategories(_ categories: Set<ToolbarItemCategory>, for source: String)
}

@MainActor
final class MessageListToolbarCapabilityAdapter: MessageListToolbarCapability {
    private let toolbar: any ToolbarProviding

    init(toolbar: any ToolbarProviding) {
        self.toolbar = toolbar
    }

    func setHiddenCategories(_ categories: Set<ToolbarItemCategory>, for source: String) {
        toolbar.setHiddenCategories(categories, for: source)
    }
}
