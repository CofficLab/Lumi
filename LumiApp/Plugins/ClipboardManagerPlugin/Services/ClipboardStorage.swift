import Foundation
import MagicKit
import OSLog

actor ClipboardStorage: SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false
    
    static let shared = ClipboardStorage()
    
    private var items: [ClipboardItem] = []
    private let fileURL: URL
    private let maxHistorySize = 500
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pluginDir = appSupport.appendingPathComponent("Lumi/ClipboardManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        self.fileURL = pluginDir.appendingPathComponent("history.json")
        
        Task {
            await load()
        }
    }
    
    func add(item: ClipboardItem) {
        // Deduplicate: if same content as first item, update timestamp (or ignore)
        if let first = items.first, first.content == item.content, first.type == item.type {
            // Move to top
            // specific to Swift structs, we need to create new one or just move existing
            // Here we just remove and insert new one to update timestamp
            items.removeFirst()
            items.insert(item, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        
        // Trim
        if items.count > maxHistorySize {
            items = Array(items.prefix(maxHistorySize))
        }
        
        if Self.verbose {
            os_log("\(Self.t)➕ 已添加剪贴板项：\(item.content.prefix(50))...")
        }
        
        save()
    }
    
    func getItems() -> [ClipboardItem] {
        return items
    }
    
    func clear() {
        let count = items.count
        items.removeAll()
        save()
        os_log("\(Self.t)🗑️ 已清空剪贴板历史（共 \(count) 项）")
    }
    
    func togglePin(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isPinned.toggle()
            save()
            if Self.verbose {
                os_log("\(Self.t)📌 已切换固定状态：\(id)")
            }
        }
    }
    
    func delete(id: UUID) {
        let wasPinned = items.first(where: { $0.id == id })?.isPinned ?? false
        items.removeAll { $0.id == id }
        save()
        if Self.verbose {
            os_log("\(Self.t)🗑️ 已删除剪贴板项：\(id)\(wasPinned ? " (已固定)" : "")")
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL)
            if Self.verbose {
                os_log("\(Self.t)💾 已保存剪贴板历史（\(self.items.count) 项）")
            }
        } catch {
            os_log(.error, "\(Self.t)❌ 保存剪贴板历史失败：\(error.localizedDescription)")
        }
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 剪贴板历史文件不存在，从空列表开始")
            }
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            os_log("\(Self.t)✅ 已加载 \(self.items.count) 个剪贴板项")
        } catch {
            os_log(.error, "\(Self.t)❌ 加载剪贴板历史失败：\(error.localizedDescription)")
        }
    }
}
