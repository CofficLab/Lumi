import LumiCoreKit
import LumiUI
import SwiftUI

public struct DebugToolbarView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    public let fileURL: URL?
    public let projectRoot: String?

    public var body: some View {
        HStack(spacing: 10) {
            Button {
                _ = launchConfiguration.flatMap(NodeDAPAdapter.commandLine)
            } label: {
                Label(LumiPluginLocalization.string("Node", bundle: .module), systemImage: "play.fill")
            }
            .buttonStyle(.borderless)
            .disabled(launchConfiguration == nil)

            Button {
                _ = BrowserCDPAdapter.defaultEndpoint().map(BrowserCDPAdapter.init(endpoint:))
            } label: {
                Label(LumiPluginLocalization.string("Browser", bundle: .module), systemImage: "safari")
            }
            .buttonStyle(.borderless)

            if let sourceMap = fileURL.flatMap(SourceMapResolver.sourceMapURL) {
                Text(sourceMap.lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    private var launchConfiguration: NodeDAPAdapter.LaunchConfiguration? {
        guard let projectRoot else { return nil }
        return NodeDAPAdapter.defaultLaunch(fileURL: fileURL, projectPath: projectRoot)
    }
}
