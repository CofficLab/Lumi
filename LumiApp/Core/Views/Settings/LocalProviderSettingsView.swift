import SwiftUI

/// 本地大模型设置视图
struct LocalProviderSettingsView: View {
    @EnvironmentObject private var registry: ProviderRegistry

    var body: some View {
        ProviderSettingsView(mode: .local)
            .environmentObject(registry)
    }
}

#Preview {
    LocalProviderSettingsView()
        .inRootView()
}
