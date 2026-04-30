import Combine
import Foundation

@MainActor
final class EditorSettingsState: ObservableObject {
    static let shared = EditorSettingsState()

    @Published var fontSize: Double = 13.0 { didSet { persistIfNeeded() } }
    @Published var tabWidth: Int = 4 { didSet { persistIfNeeded() } }
    @Published var useSpaces: Bool = true { didSet { persistIfNeeded() } }
    @Published var wrapLines: Bool = true { didSet { persistIfNeeded() } }
    @Published var showMinimap: Bool = true { didSet { persistIfNeeded() } }
    @Published var showGutter: Bool = true { didSet { persistIfNeeded() } }
    @Published var showFoldingRibbon: Bool = true { didSet { persistIfNeeded() } }
    @Published var formatOnSave: Bool = false { didSet { persistIfNeeded() } }
    @Published var organizeImportsOnSave: Bool = false { didSet { persistIfNeeded() } }
    @Published var fixAllOnSave: Bool = false { didSet { persistIfNeeded() } }
    @Published var trimTrailingWhitespaceOnSave: Bool = true { didSet { persistIfNeeded() } }
    @Published var insertFinalNewlineOnSave: Bool = true { didSet { persistIfNeeded() } }

    let supportsRenderWhitespace = false

    private let configController: EditorConfigController
    private let pluginManager: EditorPluginManager
    private var baseSnapshot: EditorConfigSnapshot
    private var suppressPersistence = true
    private var cancellables = Set<AnyCancellable>()

    private init(
        configController: EditorConfigController = EditorConfigController(),
        pluginManager: EditorPluginManager = EditorPluginManager()
    ) {
        self.configController = configController
        self.pluginManager = pluginManager
        self.baseSnapshot = configController.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })

        restore()
        reinstallEditorPlugins()
        observePluginSettingChanges()
    }

    var contributedSettings: [EditorSettingsItemSuggestion] {
        pluginManager.registry.settingsSuggestions(state: self)
    }

    func restore() {
        suppressPersistence = true
        let snapshot = configController.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })
        baseSnapshot = snapshot
        fontSize = snapshot.fontSize
        tabWidth = snapshot.tabWidth
        useSpaces = snapshot.useSpaces
        wrapLines = snapshot.wrapLines
        showMinimap = snapshot.showMinimap
        showGutter = snapshot.showGutter
        showFoldingRibbon = snapshot.showFoldingRibbon
        formatOnSave = snapshot.formatOnSave
        organizeImportsOnSave = snapshot.organizeImportsOnSave
        fixAllOnSave = snapshot.fixAllOnSave
        trimTrailingWhitespaceOnSave = snapshot.trimTrailingWhitespaceOnSave
        insertFinalNewlineOnSave = snapshot.insertFinalNewlineOnSave
        suppressPersistence = false
    }

    private var snapshot: EditorConfigSnapshot {
        EditorConfigSnapshot(
            fontSize: fontSize,
            tabWidth: tabWidth,
            useSpaces: useSpaces,
            formatOnSave: formatOnSave,
            organizeImportsOnSave: organizeImportsOnSave,
            fixAllOnSave: fixAllOnSave,
            trimTrailingWhitespaceOnSave: trimTrailingWhitespaceOnSave,
            insertFinalNewlineOnSave: insertFinalNewlineOnSave,
            wrapLines: wrapLines,
            showMinimap: showMinimap,
            showGutter: showGutter,
            showFoldingRibbon: showFoldingRibbon,
            currentThemeId: baseSnapshot.currentThemeId,
            sidePanelWidth: baseSnapshot.sidePanelWidth
        )
    }

    private func persistIfNeeded() {
        guard !suppressPersistence else { return }
        let snapshot = snapshot
        configController.persistConfig(snapshot)
        NotificationCenter.default.post(
            name: .lumiEditorSettingsDidChange,
            object: self,
            userInfo: ["snapshot": snapshot]
        )
    }

    private func reinstallEditorPlugins() {
        let plugins = PluginVM.shared.plugins.filter {
            PluginVM.shared.isPluginEnabled($0) && $0.providesEditorExtensions
        }
        pluginManager.install(plugins: plugins)
        objectWillChange.send()
    }

    private func observePluginSettingChanges() {
        NotificationCenter.default.publisher(for: .pluginSettingsChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reinstallEditorPlugins()
            }
            .store(in: &cancellables)
    }
}
