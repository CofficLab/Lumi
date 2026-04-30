import Combine
import CoreGraphics
import Foundation

enum EditorSettingsScopeSelection: String, CaseIterable, Identifiable {
    case global
    case workspace
    case language

    var id: String { rawValue }

    var title: String {
        switch self {
        case .global: return "Global"
        case .workspace: return "Workspace"
        case .language: return "Language"
        }
    }
}

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
    @Published var selectedScope: EditorSettingsScopeSelection = .global { didSet { restoreScopedOverrideDraft() } }
    @Published var selectedLanguageID: String = "swift" { didSet { restoreScopedOverrideDraft() } }
    @Published var scopedTabWidthEnabled: Bool = false { didSet { persistScopedOverrideIfNeeded() } }
    @Published var scopedTabWidth: Int = 4 { didSet { persistScopedOverrideIfNeeded() } }
    @Published var scopedUseSpacesEnabled: Bool = false { didSet { persistScopedOverrideIfNeeded() } }
    @Published var scopedUseSpaces: Bool = true { didSet { persistScopedOverrideIfNeeded() } }
    @Published var scopedWrapLinesEnabled: Bool = false { didSet { persistScopedOverrideIfNeeded() } }
    @Published var scopedWrapLines: Bool = true { didSet { persistScopedOverrideIfNeeded() } }
    @Published var scopedFormatOnSaveEnabled: Bool = false { didSet { persistScopedOverrideIfNeeded() } }
    @Published var scopedFormatOnSave: Bool = false { didSet { persistScopedOverrideIfNeeded() } }

    let supportsRenderWhitespace = false

    private let configController: EditorConfigController
    private let pluginManager: EditorPluginManager
    private let recentProjectsStore: RecentProjectsStore
    private var baseSnapshot: EditorConfigSnapshot
    private var suppressPersistence = true
    private var cancellables = Set<AnyCancellable>()

    init(
        configController: EditorConfigController = EditorConfigController(),
        pluginManager: EditorPluginManager = EditorPluginManager(),
        recentProjectsStore: RecentProjectsStore = RecentProjectsStore()
    ) {
        self.configController = configController
        self.pluginManager = pluginManager
        self.recentProjectsStore = recentProjectsStore
        self.baseSnapshot = configController.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })

        restore()
        reinstallEditorPlugins()
        observePluginSettingChanges()
    }

    var contributedSettings: [EditorSettingsItemSuggestion] {
        pluginManager.registry.settingsSuggestions(state: self)
    }

    var currentWorkspacePath: String? {
        recentProjectsStore.getCurrentProject()?.path
    }

    var availableLanguageIDs: [String] {
        EditorLanguageID.all
    }

    var canEditScopedOverrides: Bool {
        activeOverrideScope != nil
    }

    var activeOverrideScopeLabel: String {
        switch selectedScope {
        case .global:
            return "Global settings apply to every editor."
        case .workspace:
            return currentWorkspacePath ?? "Open a workspace to edit workspace overrides."
        case .language:
            return selectedLanguageID
        }
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
        restoreScopedOverrideDraft()
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
        refreshExternalSnapshotFields()
        let snapshot = snapshot
        configController.persistConfig(snapshot)
        NotificationCenter.default.post(
            name: .lumiEditorSettingsDidChange,
            object: self,
            userInfo: ["snapshot": snapshot]
        )
    }

    private func persistScopedOverrideIfNeeded() {
        guard !suppressPersistence,
              let scope = activeOverrideScope else { return }
        configController.persistOverrideSnapshot(
            currentScopedOverrideSnapshot,
            for: scope,
            clampedSidePanelWidth: { CGFloat($0) }
        )
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

    private func refreshExternalSnapshotFields() {
        let latest = configController.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })
        baseSnapshot.currentThemeId = latest.currentThemeId
        baseSnapshot.sidePanelWidth = latest.sidePanelWidth
    }

    private var activeOverrideScope: EditorConfigOverrideScope? {
        switch selectedScope {
        case .global:
            return nil
        case .workspace:
            guard let currentWorkspacePath else { return nil }
            return .workspace(currentWorkspacePath)
        case .language:
            return .language(selectedLanguageID)
        }
    }

    private var currentScopedOverrideSnapshot: EditorScopedOverrideSnapshot {
        EditorScopedOverrideSnapshot(
            tabWidth: scopedTabWidthEnabled ? scopedTabWidth : nil,
            useSpaces: scopedUseSpacesEnabled ? scopedUseSpaces : nil,
            wrapLines: scopedWrapLinesEnabled ? scopedWrapLines : nil,
            formatOnSave: scopedFormatOnSaveEnabled ? scopedFormatOnSave : nil
        )
    }

    private func restoreScopedOverrideDraft() {
        suppressPersistence = true
        let overrideSnapshot: EditorScopedOverrideSnapshot
        if let scope = activeOverrideScope {
            overrideSnapshot = configController.overrideSnapshot(
                for: scope,
                clampedSidePanelWidth: { CGFloat($0) }
            )
        } else {
            overrideSnapshot = EditorScopedOverrideSnapshot()
        }

        scopedTabWidthEnabled = overrideSnapshot.tabWidth != nil
        scopedTabWidth = overrideSnapshot.tabWidth ?? baseSnapshot.tabWidth
        scopedUseSpacesEnabled = overrideSnapshot.useSpaces != nil
        scopedUseSpaces = overrideSnapshot.useSpaces ?? baseSnapshot.useSpaces
        scopedWrapLinesEnabled = overrideSnapshot.wrapLines != nil
        scopedWrapLines = overrideSnapshot.wrapLines ?? baseSnapshot.wrapLines
        scopedFormatOnSaveEnabled = overrideSnapshot.formatOnSave != nil
        scopedFormatOnSave = overrideSnapshot.formatOnSave ?? baseSnapshot.formatOnSave
        suppressPersistence = false
    }
}
