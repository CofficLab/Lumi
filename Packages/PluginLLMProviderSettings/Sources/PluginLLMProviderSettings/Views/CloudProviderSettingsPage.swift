import ProviderLLMManager
import SwiftUI

/// 云端供应商设置页面。
@MainActor
public struct CloudProviderSettingsPage: View {
    private let manager: any LLMManaging

    public init(manager: any LLMManaging) {
        self.manager = manager
    }

    public var body: some View {
        ProviderSettingsPageContent(manager: manager, isLocal: false)
    }
}
