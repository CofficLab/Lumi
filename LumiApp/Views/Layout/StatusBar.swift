import EditorService
import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct StatusBar: View {
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @ObservedObject var pluginService: PluginService
    @StateObject private var projectVM: WindowProjectVM
    let editorCoreService: EditorCoreService
    let pluginContext: LumiPluginContext
    let lumiUIService: LumiUIService
    @ObservedObject var chatService: ChatService
    let projectPathStore: LumiCurrentProjectPathStore
    let panelLayoutState: PanelLayoutState

    init(
        pluginService: PluginService,
        editorCoreService: EditorCoreService,
        pluginContext: LumiPluginContext,
        lumiUIService: LumiUIService,
        chatService: ChatService,
        projectPathStore: LumiCurrentProjectPathStore,
        panelLayoutState: PanelLayoutState
    ) {
        self.pluginService = pluginService
        self.editorCoreService = editorCoreService
        self.pluginContext = pluginContext
        self.lumiUIService = lumiUIService
        self._chatService = ObservedObject(wrappedValue: chatService)
        self.projectPathStore = projectPathStore
        self.panelLayoutState = panelLayoutState
        _projectVM = StateObject(wrappedValue: WindowProjectVM(store: projectPathStore))
    }

    var body: some View {
        let context = pluginContext.withAdditionalDependencies { dependencies in
            dependencies.register(LumiThemeServicing.self, lumiUIService)
            dependencies.register((any LumiChatServicing).self, chatService)
            dependencies.register((any HistoryQueryService).self, chatService)
            dependencies.register(LumiCurrentProjectPathStoring.self, projectPathStore)
            dependencies.register(LumiCurrentProjectPathProviding.self, projectPathStore)
            dependencies.register(LumiEditorServicing.self, editorCoreService)
            dependencies.register(LumiBottomPanelLayoutPresenting.self, panelLayoutState)
        }
        let items = pluginService.statusBarItems(context: context)
        let leadingItems = items.filter { $0.placement == .leading }
        let centerItems = items.filter { $0.placement == .center }
        let trailingItems = items.filter { $0.placement == .trailing }

        HStack(spacing: 14) {
            ForEach(leadingItems) { item in
                StatusBarPluginButton(item: item)
            }

            Spacer()

            ForEach(centerItems) { item in
                StatusBarPluginButton(item: item)
            }

            Spacer()

            ForEach(trailingItems) { item in
                StatusBarPluginButton(item: item)
            }
        }
        .font(.caption)
        .foregroundStyle(statusBarForegroundColor)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .appSurface(style: .custom(statusBarBackgroundColor), cornerRadius: 0)
        .overlay(alignment: .top) {
            AppDivider()
        }
        .environmentObject(projectVM)
    }

    private var chromeTheme: any LumiAppChromeTheme {
        themeRegistry.chromeTheme
    }

    private var statusBarBackgroundColor: Color {
        chromeTheme.statusBarBackgroundColor()
    }

    private var statusBarForegroundColor: Color {
        chromeTheme.statusBarForegroundColor()
    }
}

private struct StatusBarPluginButton: View {
    let item: LumiStatusBarItem
    @State private var isPresented = false

    var body: some View {
        if let makeStatusBarView = item.makeStatusBarView {
            makeStatusBarView()
                .help(item.title)
        } else {
            AppIconButton(
                systemImage: item.systemImage,
                label: item.title,
                isActive: isPresented
            ) {
                NSApp.keyWindow?.makeFirstResponder(nil)
                NSApp.mainWindow?.makeFirstResponder(nil)
                isPresented.toggle()
            }
            .help(item.title)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                item.makePopoverView()
            }
        }
    }
}
