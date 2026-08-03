import LumiUI
import SwiftUI

/// Open Remote 插件的"关于"页内容
///
/// 由 `OpenRemotePlugin.pluginAboutView(kernel:)` 在插件管理面板中展示。
public struct OpenRemoteAboutView: View {
    public let pluginName: String

    public init(pluginName: String) {
        self.pluginName = pluginName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LumiPluginLocalization.string(pluginName, bundle: .module))
                .font(.title2.weight(.semibold))
            Text(LumiPluginLocalization.string("Displays a button in the header to open the current project's remote repository in browser", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}