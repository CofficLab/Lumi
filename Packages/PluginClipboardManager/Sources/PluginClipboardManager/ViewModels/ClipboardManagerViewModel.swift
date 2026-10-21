import Foundation
import AppKit

@MainActor
public class ClipboardManagerViewModel: ObservableObject {
    @Published var items: [ClipboardHistoryItem] = []
    @Published var searchText: String = ""
    
    private var allItems: [ClipboardHistoryItem] = []
    private let storage: ClipboardStorage

    /// 注入存储层。生产环境使用共享单例；单元测试注入临时数据库实例。
    public init(storage: ClipboardStorage = ClipboardStorage.shared) {
        self.storage = storage
        Task {
            await loadItems()
        }
    }
    
    public func loadItems() async {
        // Get items from actor-isolated storage and transfer to main actor
        let fetchedItems = await storage.getItems()
        self.allItems = fetchedItems
        filterItems()
    }
    
    public func filterItems() {
        if searchText.isEmpty {
            items = allItems
        } else {
            let lower = searchText.lowercased()
            items = allItems.filter { $0.searchKeywords.contains(lower) }
        }
    }
    
    public func refresh() {
        Task {
            await loadItems()
        }
    }
    
    public func delete(id: UUID) {
        Task {
            await storage.delete(id: id)
            await loadItems()
        }
    }
    
    public func togglePin(id: UUID) {
        Task {
            await storage.togglePin(id: id)
            await loadItems()
        }
    }
    
    public func clearAll() {
        Task {
            await storage.clear()
            await loadItems()
        }
    }
    
    public func copyToClipboard(_ item: ClipboardHistoryItem) {
        Self.write(item, to: .general)
    }

    @discardableResult
    public static func write(_ item: ClipboardHistoryItem, to pasteboard: NSPasteboard) -> Bool {
        pasteboard.clearContents()
        
        switch ClipboardItemType(rawValue: item.type) {
        case .text, .html, .color:
            return pasteboard.setString(item.content, forType: .string)
        case .file:
            return pasteboard.writeObjects([URL(fileURLWithPath: item.content) as NSPasteboardWriting])
        case .image:
            guard let image = NSImage(contentsOfFile: item.content) else {
                return false
            }
            return pasteboard.writeObjects([image])
        case .none:
            return pasteboard.setString(item.content, forType: .string)
        }
    }
}
