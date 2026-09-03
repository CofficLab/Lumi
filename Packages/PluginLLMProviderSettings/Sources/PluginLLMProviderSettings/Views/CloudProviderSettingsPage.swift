import ProviderLLMManager
import SwiftUI

/// 云端供应商设置页面。
@MainActor
public struct CloudProviderSettingsPage: View {
    private let manager: any LLMManaging
    private let downloadViewModel: (String) -> ProviderModelDownloadViewModel?

    public init(
        manager: any LLMManaging,
        downloadViewModel: @escaping (String) -> ProviderModelDownloadViewModel? = { _ in nil }
    ) {
        self.manager = manager
        self.downloadViewModel = downloadViewModel
    }

    public var body: some View {
        ProviderSettingsPageContent(
            manager: manager,
            isLocal: false,
            downloadViewModel: downloadViewModel
        )
    }
}
