import Foundation
import SwiftUI

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

/// 自定义快捷键条目
struct EditorKeybindingEntry: Equatable, Codable, Sendable {
    /// 命令 ID（如 "builtin.format-document"）
    let commandID: String
    /// 快捷键
    let key: String
    /// 修饰键
    let modifiers: [EditorCommandShortcut.Modifier]

    /// 转换为 EditorCommandShortcut
    var shortcut: EditorCommandShortcut {
        EditorCommandShortcut(key: key, modifiers: modifiers)
    }

    /// 序列化为字典（用于 plist 存储）
    var dictionaryValue: [String: Any] {
        [
            "commandID": commandID,
            "key": key,
            "modifiers": modifiers.map(\.rawValue),
        ]
    }

    /// 从字典反序列化
    init?(dictionary: [String: Any]) {
        guard let commandID = dictionary["commandID"] as? String,
              let key = dictionary["key"] as? String,
              let rawModifiers = dictionary["modifiers"] as? [String] else {
            return nil
        }
        self.commandID = commandID
        self.key = key
        self.modifiers = rawModifiers.compactMap { EditorCommandShortcut.Modifier(rawValue: $0) }
    }

    init(commandID: String, key: String, modifiers: [EditorCommandShortcut.Modifier]) {
        self.commandID = commandID
        self.key = key
        self.modifiers = modifiers
    }
}

/// 快捷键可配置化存储
///
/// 负责：
/// 1. 持久化用户自定义的快捷键映射
/// 2. 查询命令的自定义快捷键（如有）
/// 3. 重置为默认绑定
///
/// 优先级：用户自定义 > 默认绑定
@MainActor
final class EditorKeybindingStore: ObservableObject {
    static let shared = EditorKeybindingStore()

    /// 用户自定义的快捷键映射（commandID → entry）
    @Published private(set) var customBindings: [String: EditorKeybindingEntry] = [:]

    // MARK: - Persistence

    private static let bindingsFileName = "editor_keybindings.json"

    private var bindingsFileURL: URL {
        let dir = AppConfig.getDBFolderURL()
            .appendingPathComponent("LumiEditor", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        return dir.appendingPathComponent(Self.bindingsFileName)
    }

    private init() {
        load()
    }

    // MARK: - Public API

    /// 获取命令的快捷键（用户自定义优先，否则返回默认）
    func shortcut(for commandID: String, default: EditorCommandShortcut?) -> EditorCommandShortcut? {
        if let custom = customBindings[commandID] {
            return custom.shortcut
        }
        return `default`
    }

    /// 设置自定义快捷键
    func setBinding(commandID: String, key: String, modifiers: [EditorCommandShortcut.Modifier]) {
        let entry = EditorKeybindingEntry(
            commandID: commandID,
            key: key,
            modifiers: modifiers
        )
        customBindings[commandID] = entry
        save()
    }

    /// 移除自定义快捷键（恢复默认）
    func removeBinding(commandID: String) {
        customBindings.removeValue(forKey: commandID)
        save()
    }

    /// 重置所有快捷键为默认
    func resetAll() {
        customBindings.removeAll()
        save()
    }

    /// 检查某个快捷键是否已被其他命令占用
    func isConflict(key: String, modifiers: [EditorCommandShortcut.Modifier], excluding commandID: String) -> Bool {
        let targetDisplay = EditorCommandShortcut(key: key, modifiers: modifiers).displayText
        return customBindings.values.contains { entry in
            entry.commandID != commandID && entry.shortcut.displayText == targetDisplay
        }
    }

    /// 获取所有已注册的自定义绑定列表（用于设置 UI 展示）
    func allCustomBindings() -> [EditorKeybindingEntry] {
        Array(customBindings.values.sorted { $0.commandID < $1.commandID })
    }

    // MARK: - Load / Save

    private func load() {
        let url = bindingsFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return
        }

        do {
            let entries = try JSONDecoder().decode([EditorKeybindingEntry].self, from: data)
            var bindings: [String: EditorKeybindingEntry] = [:]
            for entry in entries {
                bindings[entry.commandID] = entry
            }
            customBindings = bindings
        } catch {
            // 解析失败时不影响功能，使用默认绑定
        }
    }

    private func save() {
        let entries = Array(customBindings.values)
        do {
            let data = try JSONEncoder().encode(entries)
            let dir = bindingsFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: bindingsFileURL, options: .atomic)
        } catch {
            // 保存失败不影响主流程
        }
    }
}
