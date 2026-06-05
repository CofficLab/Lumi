import AgentToolKit
import Foundation
import SwiftUI

/// 聊天提交能力（由内核注入）。
///
/// 右侧栏提交按钮通过这个显式 capability 读取草稿状态并触发提交，
/// 避免直接依赖宿主 SwiftUI 环境中的窗口级会话 ViewModel。
@MainActor
public struct ChatSubmitContext {
    public let canSubmitProvider: @MainActor () -> Bool
    public let draftTextProvider: @MainActor () -> String
    public let submitter: @MainActor (String) async -> Void

    public init(
        canSubmitProvider: @escaping @MainActor () -> Bool,
        draftTextProvider: @escaping @MainActor () -> String,
        submitter: @escaping @MainActor (String) async -> Void
    ) {
        self.canSubmitProvider = canSubmitProvider
        self.draftTextProvider = draftTextProvider
        self.submitter = submitter
    }

    public var canSubmit: Bool {
        canSubmitProvider() && !trimmedDraftText.isEmpty
    }

    public var draftText: String {
        draftTextProvider()
    }

    public var trimmedDraftText: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func submitDraft() async {
        let draftText = draftText
        guard canSubmit else { return }
        await submitter(draftText)
    }
}

/// 新建会话能力（由内核注入）。
///
/// 标题栏新建按钮通过这个显式 capability 创建会话并同步默认聊天模式，
/// 避免插件视图直接依赖会话、项目、LLM 三个宿主 EnvironmentObject。
@MainActor
public struct ConversationCreationContext {
    public let isProjectSelectedProvider: @MainActor () -> Bool
    public let projectNameProvider: @MainActor () -> String
    public let projectPathProvider: @MainActor () -> String
    public let languagePreferenceProvider: @MainActor () -> LanguagePreference
    public let currentChatModeProvider: @MainActor () -> ChatMode
    public let defaultChatModeProvider: @MainActor () -> ChatMode?
    public let defaultChatModeSaver: @MainActor (ChatMode) -> Void
    public let conversationCreator: @MainActor (String?, String?, LanguagePreference, ChatMode?) async -> Void

    public init(
        isProjectSelectedProvider: @escaping @MainActor () -> Bool,
        projectNameProvider: @escaping @MainActor () -> String,
        projectPathProvider: @escaping @MainActor () -> String,
        languagePreferenceProvider: @escaping @MainActor () -> LanguagePreference,
        currentChatModeProvider: @escaping @MainActor () -> ChatMode,
        defaultChatModeProvider: @escaping @MainActor () -> ChatMode?,
        defaultChatModeSaver: @escaping @MainActor (ChatMode) -> Void,
        conversationCreator: @escaping @MainActor (String?, String?, LanguagePreference, ChatMode?) async -> Void
    ) {
        self.isProjectSelectedProvider = isProjectSelectedProvider
        self.projectNameProvider = projectNameProvider
        self.projectPathProvider = projectPathProvider
        self.languagePreferenceProvider = languagePreferenceProvider
        self.currentChatModeProvider = currentChatModeProvider
        self.defaultChatModeProvider = defaultChatModeProvider
        self.defaultChatModeSaver = defaultChatModeSaver
        self.conversationCreator = conversationCreator
    }

    public func syncDefaultChatMode() {
        defaultChatModeSaver(currentChatModeProvider())
    }

    public func createConversation() async {
        let isProjectSelected = isProjectSelectedProvider()
        let projectName = isProjectSelected ? projectNameProvider() : nil
        let projectPath = isProjectSelected ? projectPathProvider() : nil
        let chatMode = defaultChatModeProvider() ?? currentChatModeProvider()
        await conversationCreator(projectName, projectPath, languagePreferenceProvider(), chatMode)
    }
}

/// 新建会话偏好存储。
///
/// 与 ConversationNewPlugin 旧存储路径保持一致：
/// `<databaseDirectory>/ConversationNewPlugin/settings.plist`。
public final class ConversationCreationPreferenceStore: @unchecked Sendable {
    private enum Keys {
        static let defaultChatMode = "default_chat_mode"
    }

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "LumiCoreKit.ConversationCreationPreferenceStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL

    public convenience init(databaseDirectory: URL) {
        self.init(settingsDirectory: databaseDirectory.appendingPathComponent("ConversationNewPlugin", isDirectory: true))
    }

    public init(settingsDirectory: URL) {
        self.pluginDirectory = settingsDirectory
        self.settingsFileURL = settingsDirectory.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = settingsDirectory.appendingPathComponent("settings.corrupt.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    public func loadDefaultChatMode() -> ChatMode? {
        guard let rawValue = string(forKey: Keys.defaultChatMode) else { return nil }
        return ChatMode(rawValue: rawValue)
    }

    public func saveDefaultChatMode(_ chatMode: ChatMode) {
        set(chatMode.rawValue, forKey: Keys.defaultChatMode)
    }

    private func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var dict = readDict()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            writeDict(dict)
        }
    }

    private func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    private func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            quarantineCorruptSettings()
            return [:]
        }
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            return
        }

        let tmpURL = pluginDirectory.appendingPathComponent("settings.tmp")

        do {
            try data.write(to: tmpURL, options: .atomic)

            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }

    private func quarantineCorruptSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: settingsFileURL, to: corruptSettingsFileURL)
        } catch {
            try? fileManager.removeItem(at: settingsFileURL)
        }
    }
}

/// 模型选择入口能力（由内核注入）。
///
/// 模型选择 toolbar 入口只需要显示当前选择并打开详情视图。通过显式 capability
/// 提供这两个能力，避免入口视图直接依赖宿主环境对象。
@MainActor
public struct ModelSelectionContext {
    public let displayTextProvider: @MainActor () -> String
    public let detailViewProvider: @MainActor () -> AnyView

    public init(
        displayTextProvider: @escaping @MainActor () -> String,
        detailViewProvider: @escaping @MainActor () -> AnyView
    ) {
        self.displayTextProvider = displayTextProvider
        self.detailViewProvider = detailViewProvider
    }

    public var displayText: String {
        displayTextProvider()
    }

    public func detailView() -> AnyView {
        detailViewProvider()
    }
}

/// 布局菜单控制能力（由内核注入）。
///
/// 插件菜单通过 Binding 读写布局状态，不直接依赖宿主 WindowLayoutVM。
@MainActor
public struct LayoutControlContext {
    public let editorVisible: Binding<Bool>
    public let contentPanelVisible: Binding<Bool>
    public let bottomPanelVisible: Binding<Bool>
    public let railVisible: Binding<Bool>
    public let rightSidebarVisible: Binding<Bool>

    public init(
        editorVisible: Binding<Bool>,
        contentPanelVisible: Binding<Bool>,
        bottomPanelVisible: Binding<Bool>,
        railVisible: Binding<Bool>,
        rightSidebarVisible: Binding<Bool>
    ) {
        self.editorVisible = editorVisible
        self.contentPanelVisible = contentPanelVisible
        self.bottomPanelVisible = bottomPanelVisible
        self.railVisible = railVisible
        self.rightSidebarVisible = rightSidebarVisible
    }
}
