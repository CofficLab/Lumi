import ProviderLLMManager
import SwiftUI

/// 本地供应商设置页面。
@MainActor
public struct LocalProviderSettingsPage: View {
    private let manager: any LLMManaging

    public init(manager: any LLMManaging) {
        self.manager = manager
    }

    public var body: some View {
        ProviderSettingsPageContent(manager: manager, isLocal: true)
    }
}
