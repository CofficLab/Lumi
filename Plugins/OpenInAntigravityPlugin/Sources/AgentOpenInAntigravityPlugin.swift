import LumiCoreKit
import LumiUI
import AppKit
import SwiftUI

/// 在 Antigravity 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 Antigravity 编辑器中打开当前项目。
public enum AgentOpenInAntigravityPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-in-antigravity",
        displayName: LumiPluginLocalization.string("Open in Antigravity", bundle: .module),
        description: LumiPluginLocalization.string("Open current project in Antigravity editor", bundle: .module),
        order: 83,
        category: .general,
        policy: .optOut,
        stage: .beta,
        iconName: "paperplane",
    )

    @MainActor
    public static func statusBarItems(context: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        guard let lumiCore = context.lumiCore else { return [] }
        return [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .leading,
                statusBarView: {
                    OpenInAntigravityStatusBarView(lumiCore: lumiCore)
                }
            )
        ]
    }

        @MainActor
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

}

private enum AntigravityOpener {
    static func open(_ url: URL) {
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: "com.google.antigravity")
            ?? workspace.urlForApplication(withBundleIdentifier: "com.googlelabs.antigravity")
            ?? fallbackApplicationURL
        else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.open([url], withApplicationAt: appURL, configuration: configuration)
    }

    private static var fallbackApplicationURL: URL? {
        let path = "/Applications/Antigravity.app"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}

// MARK: - Status Bar View

/// Antigravity 打开状态栏视图
public struct OpenInAntigravityStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    

    public var body: some View {
        Group {
            if (lumiCore.projectComponent.currentProject?.path ?? "").isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInAntigravityDetailView(lumiCore: lumiCore),
            id: "open-in-antigravity-status"
        ) {
            Button(action: {
                openInAntigravity()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane")
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(LumiPluginLocalization.string("在 Antigravity 中打开当前项目", bundle: .module))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "paperplane")
                .resizable()
                .frame(width: 10, height: 10)

            Text(LumiPluginLocalization.string("Antigravity", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(LumiPluginLocalization.string("无项目", bundle: .module))
    }

    private func openInAntigravity() {
        guard let path = lumiCore.projectComponent.currentProject?.path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: lumiCore.projectComponent.currentProject?.path ?? "")
        AntigravityOpener.open(url)
    }
}

// MARK: - Detail View

/// Antigravity 打开详情视图（在 popover 中显示）
public struct OpenInAntigravityDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "paperplane")
                    .resizable()
                    .frame(width: 16, height: 16)

                Text(LumiPluginLocalization.string("Antigravity", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInAntigravity()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text(LumiPluginLocalization.string("打开", bundle: .module))
                    }
                    .font(.appCaption)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: 8) {
                Text(LumiPluginLocalization.string("项目", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 50, alignment: .leading)

                Text(lumiCore.projectComponent.currentProject?.path ?? "")
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lumiCore.projectComponent.currentProject?.path ?? "", forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.appCaption)
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("复制路径", bundle: .module))
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func openInAntigravity() {
        guard let path = lumiCore.projectComponent.currentProject?.path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: lumiCore.projectComponent.currentProject?.path ?? "")
        AntigravityOpener.open(url)
    }
}
