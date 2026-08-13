import AppKit
import KernelLumi
import LumiUI
import SwiftUI

/// 在 Antigravity 中打开项目插件
///
/// 在状态栏添加图标，点击后在 Antigravity 编辑器中打开当前项目。当前项目路径由内核的
/// `ProjectProviding` 提供（响应式）。
@MainActor
public final class AgentOpenInAntigravityPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-in-antigravity"
    public var name: String {
        LumiPluginLocalization.string("Open in Antigravity", bundle: .module)
    }
    public let order = 83
    public let category: LumiPluginCategory = .open
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}
    public func onReady(kernel: KernelLumi) async throws {}

    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] {
        guard let project = kernel.project else { return [] }
        return [
            StatusBarItem(
                id: "\(id).status",
                title: name,
                systemImage: "paperplane",
                placement: .leading,
                statusBarView: {
                    OpenInAntigravityStatusBarView(project: project)
                }
            )
        ]
    }

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(LumiPluginLocalization.string("Open in Antigravity", bundle: .module))
                    .font(.title2.weight(.semibold))
                Text(LumiPluginLocalization.string("Open current project in Antigravity editor", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
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
    @LumiTheme private var theme: any LumiUITheme
    @StateObject private var observer: ProjectPathObserver

    public init(project: any ProjectProviding) {
        self._observer = StateObject(wrappedValue: ProjectPathObserver(project: project))
    }

    private var currentProjectPath: String {
        observer.path
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
            detailView: OpenInAntigravityDetailView(path: currentProjectPath),
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
        .help(LumiPluginLocalization.string("无项目", bundle: .module))
    }

    private func openInAntigravity() {
        guard !currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: currentProjectPath)
        AntigravityOpener.open(url)
    }
}

// MARK: - Detail View

/// Antigravity 打开详情视图（在 popover 中显示）
public struct OpenInAntigravityDetailView: View {
    @LumiTheme private var theme: any LumiUITheme
    let path: String

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

                Text(path)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
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
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        AntigravityOpener.open(url)
    }
}
