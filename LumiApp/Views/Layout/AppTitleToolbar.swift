import LumiCoreKit
import AppKit
import LumiUI
import SwiftUI

/// Self-rendered title toolbar for the main window.
///
/// The plugin contribution points stay the same as the old system toolbar:
/// leading, center, and trailing views are collected by `AppPluginVM`.
struct AppTitleToolbar: View {
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var conversationListContext: ConversationListContext
    @EnvironmentObject private var llmVM: AppLLMVM
    @Environment(\.windowContainer) private var windowContainer

    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    var body: some View {
        let activeIcon = layoutVM.activeViewContainerIcon
        let activeContainer = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let pluginContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            showChat: activeContainer?.showChat ?? .hidden,
            showsProjectToolbar: activeContainer?.showsProjectToolbar ?? false,
            showsRail: activeContainer?.showsRail ?? false,
            showsBottomPanel: activeContainer?.showsBottomPanel ?? false,
            windowId: windowContainer?.id,
            languagePreference: windowContainer?.projectVM.languagePreference ?? .current,
            conversationCreationContext: makeConversationCreationContext(),
            layoutControlContext: makeLayoutControlContext(),
            conversationListContext: conversationListContext
        )
        let leadingViews = pluginProvider.getToolbarLeadingViews(context: pluginContext)
        let centerViews = pluginProvider.getToolbarCenterViews(context: pluginContext)
        let trailingViews = pluginProvider.getToolbarTrailingViews(context: pluginContext)
        let theme = themeVM.activeChromeTheme

        ZStack {
            WindowDragRegion()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                Color.clear
                    .frame(width: trafficLightReserveWidth, height: height)
                    .accessibilityHidden(true)

                toolbarGroup(leadingViews, idPrefix: "title_toolbar_leading")

                Spacer(minLength: 12)

                toolbarGroup(trailingViews, idPrefix: "title_toolbar_trailing")
            }
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            toolbarGroup(centerViews, idPrefix: "title_toolbar_center")
                .frame(maxWidth: 420)
                .padding(.horizontal, trafficLightReserveWidth + 12)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .foregroundColor(theme.workspaceTextColor())
        .background(theme.sidebarBackgroundColor())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.statusBarDividerColor())
                .frame(height: 1)
        }
    }

    private func toolbarGroup(_ views: [AnyView], idPrefix: String) -> some View {
        HStack(spacing: 8) {
            ForEach(views.indices, id: \.self) { index in
                views[index]
                    .id("\(idPrefix)_\(index)")
            }
        }
        .frame(height: height)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func makeConversationCreationContext() -> ConversationCreationContext? {
        windowContainer?.makeConversationCreationContext(llmVM: llmVM)
    }

    private func makeLayoutControlContext() -> LayoutControlContext {
        LayoutControlContext(
            editorVisible: $layoutVM.editorVisible,
            contentPanelVisible: $layoutVM.contentPanelVisible,
            bottomPanelVisible: $layoutVM.bottomPanelVisible,
            railVisible: $layoutVM.railVisible,
            rightSidebarVisible: $layoutVM.rightSidebarVisible
        )
    }
}

private extension WindowContainer {
    func makeConversationCreationContext(llmVM: AppLLMVM) -> ConversationCreationContext {
        ConversationCreationContext(
            isProjectSelectedProvider: { [weak self] in
                self?.projectVM.isProjectSelected ?? false
            },
            projectNameProvider: { [weak self] in
                self?.projectVM.currentProjectName ?? ""
            },
            projectPathProvider: { [weak self] in
                self?.projectVM.currentProjectPath ?? ""
            },
            languagePreferenceProvider: { [weak self] in
                self?.projectVM.languagePreference ?? .current
            },
            currentChatModeProvider: { [weak llmVM] in
                guard let rawValue = llmVM?.chatMode.rawValue else { return .build }
                return LumiCoreKit.ChatMode(rawValue: rawValue) ?? .build
            },
            defaultChatModeProvider: { [weak self] in
                guard self != nil else { return nil }
                let databaseDirectory = AppConfig.getDBFolderURL()
                return ConversationCreationPreferenceStore(databaseDirectory: databaseDirectory).loadDefaultChatMode()
            },
            defaultChatModeSaver: { [weak self] chatMode in
                guard self != nil else { return }
                let databaseDirectory = AppConfig.getDBFolderURL()
                ConversationCreationPreferenceStore(databaseDirectory: databaseDirectory).saveDefaultChatMode(chatMode)
            },
            conversationCreator: { [weak self] projectName, projectPath, languagePreference, chatMode in
                let appChatMode = chatMode.flatMap { ChatMode(rawValue: $0.rawValue) }
                await self?.conversationVM.createNewConversation(
                    projectName: projectName,
                    projectPath: projectPath,
                    languagePreference: languagePreference,
                    chatMode: appChatMode
                )
            }
        )
    }
}

private struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DragRegionView {
        DragRegionView()
    }

    func updateNSView(_ nsView: DragRegionView, context: Context) {}
}

private final class DragRegionView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}

#Preview("App Title Toolbar") {
    AppTitleToolbar()
        .inRootView(container: WindowContainer(container: RootContainer.shared))
        .frame(width: 900)
}
