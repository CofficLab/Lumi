import SwiftUI

/// 云端大模型设置视图
struct RemoteProviderSettingsView: View {
    @EnvironmentObject private var registry: ProviderRegistry

    var body: some View {
        ProviderSettingsView(mode: .remote)
            .environmentObject(registry)
    }
}

#Preview {
    RemoteProviderSettingsView()
        .inRootView()
}
