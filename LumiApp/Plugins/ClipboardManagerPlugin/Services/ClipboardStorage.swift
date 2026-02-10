import Foundation
import OSLog

actor ClipboardStorage {
    static let shared = ClipboardStorage()
    
    private var items: [ClipboardItem] = []
    private let fileURL: URL
    private let logger = Logger(subsystem: "com.lumi.clipboard", category: "Storage")
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
            var updated = first
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
        
        save()
    }
    
    func getItems() -> [ClipboardItem] {
        return items
    }
    
    func clear() {
        items.removeAll()
        save()
    }
    
    func togglePin(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isPinned.toggle()
            save()
        }
    }
    
    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL)
        } catch {
            os_log(.error, "Failed to save history: %s", error.localizedDescription)
        }
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            os_log(.info, "Loaded %d items", self.items.count) 
        } catch {
            os_log(.error, "Failed to load history: %s", error.localizedDescription)
        }
    }
}
