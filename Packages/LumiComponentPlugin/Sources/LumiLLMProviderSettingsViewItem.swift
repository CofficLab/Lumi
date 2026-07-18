import LumiComponentLLMProvider
import LumiComponentMessage
import SwiftUI

/// A provider-specific settings detail view contributed by an LLM provider plugin.
@MainActor
public struct LumiLLMProviderSettingsViewItem {
    public let providerID: String
    private let contentBuilder: @MainActor (LumiLLMProviderInfo) -> AnyView

    public init<Content: View>(
        providerID: String,
        @ViewBuilder content: @escaping @MainActor (LumiLLMProviderInfo) -> Content
    ) {
        self.providerID = providerID
        self.contentBuilder = { AnyView(content($0)) }
    }

    public func makeContent(for provider: LumiLLMProviderInfo) -> AnyView {
        contentBuilder(provider)
    }
}

/// Aggregates provider-specific settings views from enabled plugins.
@MainActor
public protocol LumiLLMProviderSettingsContributing: AnyObject {
    func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem]
}
