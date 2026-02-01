import Foundation
import Combine

@MainActor
class XcodeCleanerViewModel: ObservableObject {
    @Published var itemsByCategory: [XcodeCleanCategory: [XcodeCleanItem]] = [:]
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var errorMessage: String?
    
    // 统计
    var totalSize: Int64 {
        itemsByCategory.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        itemsByCategory.values.flatMap { $0 }.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    private let service = XcodeCleanService.shared
    
    func scanAll() async {
        isScanning = true
        errorMessage = nil
        itemsByCategory = [:]
        
        await withTaskGroup(of: (XcodeCleanCategory, [XcodeCleanItem]).self) { group in
            for category in XcodeCleanCategory.allCases {
                group.addTask {
                    let items = await self.service.scan(category: category)
                    return (category, items)
                }
            }
            
            for await (category, items) in group {
                var processedItems = items
                
                // 应用智能选择策略
                applyAutoSelection(for: category, items: &processedItems)
                
                self.itemsByCategory[category] = processedItems
            }
        }
        
        isScanning = false
    }
    
    func toggleSelection(for item: XcodeCleanItem) {
        guard var items = itemsByCategory[item.category] else { return }
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isSelected.toggle()
            itemsByCategory[item.category] = items
        }
    }
    
    func selectAll(in category: XcodeCleanCategory) {
        guard var items = itemsByCategory[category] else { return }
        for i in 0..<items.count {
            items[i].isSelected = true
        }
        itemsByCategory[category] = items
    }
    
    func deselectAll(in category: XcodeCleanCategory) {
        guard var items = itemsByCategory[category] else { return }
        for i in 0..<items.count {
            items[i].isSelected = false
        }
        itemsByCategory[category] = items
    }
    
    func cleanSelected() async {
        isCleaning = true
        let itemsToDelete = itemsByCategory.values.flatMap { $0 }.filter { $0.isSelected }
        
        do {
            try await service.delete(items: itemsToDelete)
            // 重新扫描或直接从列表中移除
            await scanAll()
        } catch {
            errorMessage = "清理失败: \(error.localizedDescription)"
        }
        
        isCleaning = false
    }
    
    // MARK: - Auto Selection Logic
    
    private func applyAutoSelection(for category: XcodeCleanCategory, items: inout [XcodeCleanItem]) {
        switch category {
        case .derivedData, .simulatorCaches, .logs:
            // 默认全选
            for i in 0..<items.count {
                items[i].isSelected = true
            }
            
        case .iOSDeviceSupport, .watchOSDeviceSupport, .tvOSDeviceSupport:
            // 保留最新版本，其余选中
            // 排序：版本号从高到低
            // 简单解析：假设名称开头是版本号
            
            let sortedIndices = items.indices.sorted { (i, j) -> Bool in
                let v1 = items[i].name
                let v2 = items[j].name
                return v1.compare(v2, options: .numeric) == .orderedDescending // 降序
            }
            
            // 选中除了第一个（最新）之外的所有
            for (rank, index) in sortedIndices.enumerated() {
                if rank > 0 { // 0 是最新的
                    items[index].isSelected = true
                }
            }
            
        case .archives:
            // 默认不选
            break
        }
    }
    
    // MARK: - Formatting
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
