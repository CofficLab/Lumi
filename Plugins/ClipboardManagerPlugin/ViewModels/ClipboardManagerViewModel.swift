import Foundation
import Combine
import AppKit

@MainActor
class ClipboardManagerViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchText: String = ""
    
    private var allItems: [ClipboardItem] = []
    private let storage = ClipboardStorage.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Task {
            await loadItems()
        }
        
        NotificationCenter.default.publisher(for: .clipboardHistoryDidUpdate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }
    
    func loadItems() async {
        self.allItems = await storage.getItems()
        filterItems()
    }
    
    func filterItems() {
        if searchText.isEmpty {
            items = allItems
        } else {
            let lower = searchText.lowercased()
            items = allItems.filter { $0.searchKeywords.contains(lower) }
        }
    }
    
    func refresh() {
        Task {
            await loadItems()
        }
    }
    
    func delete(id: UUID) {
        Task {
            await storage.delete(id: id)
            await loadItems()
        }
    }
    
    func togglePin(id: UUID) {
        Task {
            await storage.togglePin(id: id)
            await loadItems()
        }
    }
    
    func clearAll() {
        Task {
            await storage.clear()
            await loadItems()
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .html, .color:
            pasteboard.setString(item.content, forType: .string)
        case .file:
            // Assuming content is path
            pasteboard.writeObjects([URL(fileURLWithPath: item.content) as NSPasteboardWriting])
        case .image:
            // Implement image copy
            break
        }
        
        // Notify or feedback?
    }
}
