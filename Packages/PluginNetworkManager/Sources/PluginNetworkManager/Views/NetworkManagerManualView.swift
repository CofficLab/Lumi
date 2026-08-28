import LumiUI
import SwiftUI

/// Network Manager 插件使用手册
struct NetworkManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Network Manager"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the Network Manager, which lets you inspect and control network access for applications on your Mac."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Main Panel"))
            ManualBulletList(items: [
                .init(L("Application list: shows all apps with their current network access status.")),
                .init(L("Toggle switch: enable or disable network access for each app.")),
                .init(L("Connection details: view active connections, protocols, and remote endpoints.")),
            ])

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Network Manager panel from the sidebar.")),
                .init(L("Browse the application list to find the app you want to manage.")),
                .init(L("Toggle the switch to allow or block network access for an app.")),
                .init(L("Click on an app to view detailed connection information.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Changes take effect immediately; no restart required.")),
                .init(L("Some system services may require elevated privileges to manage.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        NetworkManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
