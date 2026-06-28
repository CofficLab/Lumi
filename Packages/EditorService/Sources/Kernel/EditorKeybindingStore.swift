import EditorKernel
import Foundation
import os
import SuperLogKit
import SwiftUI

private let editorKeybindingsFileName = "editor_keybindings.json"
private let corruptEditorKeybindingsFileName = "editor_keybindings.corrupt.json"

// MARK: - Editor Keybinding Store
//
// 后续方向：键位可配置化。
//
// 允许用户覆盖默认快捷键绑定，覆盖后的绑定持久化到本地 plist 文件。
//
// 架构：
// 1. `EditorKeybindingStore` — 管理自定义快捷键映射（读取/保存/查询）
// 2. 与 `CommandRegistry` 配合 — 注册命令时查询是否有用户覆盖
// 3. 命令面板/toolbar — 显示生效的快捷键（默认 or 用户覆盖）

/// 快捷键可配置化存储
///
/// 负责：
/// 1. 持久化用户自定义的快捷键映射
/// 2. 查询命令的自定义快捷键（如有）
/// 3. 重置为默认绑定
///
/// 优先级：用户自定义 > 默认绑定
@MainActor
public final class EditorKeybindingStore: ObservableObject, SuperLog {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.keybinding-store")

    public static let shared = EditorKeybindingStore()

    /// 用户自定义的快捷键映射（commandID → entry）
    @Published public private(set) var customBindings: [String: EditorKeybindingEntry] = [:]

    private let customBindingsFileURL: URL?

    // MARK: - Persistence

    private var bindingsFileURL: URL {
        Self.bindingsFileURL(
            persistenceRootURL: EditorSettingsLifecycle.hostPersistenceRootURL?(),
            applicationSupportURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory,
            storageDirectoryName: EditorHostEnvironment.current.storageDirectoryName
        )
    }

    nonisolated static func bindingsFileURL(
        persistenceRootURL: URL?,
        applicationSupportURL: URL,
        storageDirectoryName: String
    ) -> URL {
        let base = persistenceRootURL ?? applicationSupportURL
        return base
            .appendingPathComponent(storageDirectoryName, isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
            .appendingPathComponent(editorKeybindingsFileName)
    }

    nonisolated static func corruptBindingsFileURL(for bindingsFileURL: URL) -> URL {
        bindingsFileURL
            .deletingLastPathComponent()
            .appendingPathComponent(corruptEditorKeybindingsFileName)
    }

    private convenience init() {
        self.init(bindingsFileURL: nil)
    }

    init(bindingsFileURL: URL?) {
        self.customBindingsFileURL = bindingsFileURL
        load()
    }

    // MARK: - Public API

    /// 获取命令的快捷键（用户自定义优先，否则返回默认）
    public func shortcut(for commandID: String, default: EditorCommandShortcut?) -> EditorCommandShortcut? {
        if let custom = customBindings[commandID] {
            return custom.shortcut
        }
        return `default`
    }

    /// 设置自定义快捷键
    @discardableResult
    public func setBinding(commandID: String, key: String, modifiers: [EditorCommandShortcut.Modifier]) -> Bool {
        let entry = EditorKeybindingEntry(
            commandID: commandID,
            key: key,
            modifiers: modifiers
        )
        customBindings[commandID] = entry
        return save()
    }

    /// 移除自定义快捷键（恢复默认）
    @discardableResult
    public func removeBinding(commandID: String) -> Bool {
        customBindings.removeValue(forKey: commandID)
        return save()
    }

    /// 重置所有快捷键为默认
    @discardableResult
    public func resetAll() -> Bool {
        customBindings.removeAll()
        return save()
    }

    /// 检查某个快捷键是否已被其他命令占用
    public func isConflict(key: String, modifiers: [EditorCommandShortcut.Modifier], excluding commandID: String) -> Bool {
        let targetDisplay = EditorCommandShortcut(key: key, modifiers: modifiers).displayText
        return customBindings.values.contains { entry in
            entry.commandID != commandID && entry.shortcut.displayText == targetDisplay
        }
    }

    /// 获取所有已注册的自定义绑定列表（用于设置 UI 展示）
    public func allCustomBindings() -> [EditorKeybindingEntry] {
        Array(customBindings.values.sorted { $0.commandID < $1.commandID })
    }

    // MARK: - Load / Save

    private func load() {
        let url = storageURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([EditorKeybindingEntry].self, from: data)
            var bindings: [String: EditorKeybindingEntry] = [:]
            for entry in entries {
                bindings[entry.commandID] = entry
            }
            customBindings = bindings
        } catch {
            Self.logger.error("\(Self.t)Load editor keybindings failed: \(error.localizedDescription)")
            quarantineCorruptBindings(at: url)
        }
    }

    @discardableResult
    private func save() -> Bool {
        let entries = Array(customBindings.values)
        let url = storageURL
        do {
            let data = try JSONEncoder().encode(entries)
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            Self.logger.error("\(Self.t)Save editor keybindings failed: \(error.localizedDescription)")
            return false
        }
    }

    private var storageURL: URL {
        customBindingsFileURL ?? bindingsFileURL
    }

    private func quarantineCorruptBindings(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let corruptURL = Self.corruptBindingsFileURL(for: url)
        do {
            if FileManager.default.fileExists(atPath: corruptURL.path) {
                try FileManager.default.removeItem(at: corruptURL)
            }
            try FileManager.default.moveItem(at: url, to: corruptURL)
        } catch {
            Self.logger.error("\(Self.t)Quarantine corrupt editor keybindings failed: \(error.localizedDescription)")
        }
    }
}
