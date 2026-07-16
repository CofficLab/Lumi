import LumiCoreKit
import LumiUI
import AppKit
import SwiftUI
import os

/// 在 Cursor 中打开项目插件
public enum AgentOpenInCursorPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.open-in-cursor")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-in-cursor",
        displayName: LumiPluginLocalization.string("Open in Cursor", bundle: .module),
        description: LumiPluginLocalization.string("Open current project in Cursor editor", bundle: .module),
        order: 82,
        category: .general,
        policy: .optOut,
        stage: .beta,
        iconName: "chevron.left.forwardslash.chevron.right",
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
                    OpenInCursorStatusBarView(lumiCore: lumiCore)
                }
            )
        ]
    }

        @MainActor
    public static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
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

private enum CursorOpener {
    static func open(_ url: URL) {
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: "com.todesktop.230313mzl4w4u92")
            ?? (FileManager.default.fileExists(atPath: "/Applications/Cursor.app")
                ? URL(fileURLWithPath: "/Applications/Cursor.app")
                : nil)
        else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.open([url], withApplicationAt: appURL, configuration: configuration)
    }
}

// MARK: - Status Bar View

/// Cursor 打开状态栏视图
public struct OpenInCursorStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        Group {
            if (lumiCore.projectState?.currentProject?.path ?? "").isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInCursorDetailView(lumiCore: lumiCore),
            id: "open-in-cursor-status"
        ) {
            Button(action: {
                openInCursor()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.appCaption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(LumiPluginLocalization.string("在 Cursor 中打开当前项目", bundle: .module))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.appMicro)

            Text(LumiPluginLocalization.string("Cursor", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(LumiPluginLocalization.string("无项目", bundle: .module))
    }

    private func openInCursor() {
        guard let path = lumiCore.projectState?.currentProject?.path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: lumiCore.projectState?.currentProject?.path ?? "")
        CursorOpener.open(url)
    }
}

// MARK: - Detail View

/// Cursor 打开详情视图（在 popover 中显示）
public struct OpenInCursorDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.appBodyEmphasized)

                Text(LumiPluginLocalization.string("Cursor", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInCursor()
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

                Text(lumiCore.projectState?.currentProject?.path ?? "")
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lumiCore.projectState?.currentProject?.path ?? "", forType: .string)
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

    private func openInCursor() {
        guard let path = lumiCore.projectState?.currentProject?.path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: lumiCore.projectState?.currentProject?.path ?? "")
        CursorOpener.open(url)
    }
}
