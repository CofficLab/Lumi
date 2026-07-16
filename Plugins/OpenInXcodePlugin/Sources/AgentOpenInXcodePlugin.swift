import AppKit
import LumiCoreKit
import LumiUI
import SwiftUI

/// 在 Xcode 中打开项目插件
public enum AgentOpenInXcodePlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-in-xcode",
        displayName: LumiPluginLocalization.string("Open in Xcode", bundle: .module),
        description: LumiPluginLocalization.string("Displays a button in the header to open the current project in Xcode", bundle: .module),
        order: 95,
        category: .general,
        policy: .optOut,
        stage: .beta,
        iconName: "hammer",
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard let lumiCore = context.lumiCore else { return [] }
        return [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .leading,
                statusBarView: {
                    OpenInXcodeStatusBarView(lumiCore: lumiCore)
                }
            )
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
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

private enum XcodeOpener {
    static func open(_ url: URL) {
        let workspace = NSWorkspace.shared
        let xcodeURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode")
            ?? URL(fileURLWithPath: "/Applications/Xcode.app")
        let configuration = NSWorkspace.OpenConfiguration()
        workspace.open([url], withApplicationAt: xcodeURL, configuration: configuration)
    }
}

// MARK: - Status Bar View

/// Xcode 打开状态栏视图
public struct OpenInXcodeStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        Group {
            if currentProjectPath.isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInXcodeDetailView(lumiCore: lumiCore),
            id: "open-in-xcode-status"
        ) {
            Button(action: {
                openInXcode()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.appCaption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(LumiPluginLocalization.string("在 Xcode 中打开当前项目", bundle: .module))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer.fill")
                .font(.appMicro)

            Text(LumiPluginLocalization.string("Xcode", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(LumiPluginLocalization.string("无项目", bundle: .module))
    }

    private func openInXcode() {
        guard !currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: currentProjectPath)
        XcodeOpener.open(url)
    }
}

// MARK: - Detail View

/// Xcode 打开详情视图（在 popover 中显示）
public struct OpenInXcodeDetailView: View {
    let lumiCore: LumiCoreAccessing
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Xcode", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInXcode()
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

                Text(currentProjectPath)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(currentProjectPath, forType: .string)
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

    private func openInXcode() {
        guard !currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: currentProjectPath)
        XcodeOpener.open(url)
    }
}
