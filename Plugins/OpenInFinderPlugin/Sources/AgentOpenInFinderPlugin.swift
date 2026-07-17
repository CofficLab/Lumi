import AppKit
import LumiCoreKit
import LumiUI
import SwiftUI

/// 在 Finder 中打开项目插件
public enum AgentOpenInFinderPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-in-finder",
        displayName: LumiPluginLocalization.string("Open in Finder", bundle: .module),
        description: LumiPluginLocalization.string("Open current project in Finder", bundle: .module),
        order: 96,
        category: .general,
        policy: .optOut,
        stage: .beta,
        iconName: "folder",
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
                    OpenInFinderStatusBarView(lumiCore: lumiCore)
                }
            ),
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

// MARK: - Status Bar View

/// Finder 打开状态栏视图
public struct OpenInFinderStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        Group {
            if (lumiCore.projectComponent?.currentProject?.path ?? "").isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInFinderDetailView(lumiCore: lumiCore),
            id: "open-in-finder-status"
        ) {
            Button(action: {
                openInFinder()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.appCaption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(LumiPluginLocalization.string("在 Finder 中打开当前项目", bundle: .module))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.appMicro)

            Text(LumiPluginLocalization.string("Finder", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(LumiPluginLocalization.string("无项目", bundle: .module))
    }

    private func openInFinder() {
        guard let path = lumiCore.projectComponent?.currentProject?.path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: lumiCore.projectComponent?.currentProject?.path ?? "")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Detail View

/// Finder 打开详情视图（在 popover 中显示）
public struct OpenInFinderDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Finder", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInFinder()
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

                Text(lumiCore.projectComponent?.currentProject?.path ?? "")
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lumiCore.projectComponent?.currentProject?.path ?? "", forType: .string)
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

    private func openInFinder() {
        guard let path = lumiCore.projectComponent?.currentProject?.path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: lumiCore.projectComponent?.currentProject?.path ?? "")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
