import Foundation
import AppKit

@MainActor
public class ClipboardManagerViewModel: ObservableObject {
    @Published var items: [ClipboardHistoryItem] = []
    @Published var searchText: String = ""
    
    private var allItems: [ClipboardHistoryItem] = []
    private let storage: ClipboardStorage

    /// 待执行的搜索任务。
    ///
    /// 搜索扫描最多 5000 条全文记录，原先每次按键都在主线程同步扫描一遍
    /// （见 issue #1192）。这里用任务防抖 + 后台扫描 + 只保留最新查询结果。
    private var searchTask: Task<Void, Never>?

    /// 面板是否可见。隐藏时剪贴板变化不应触发任何主 actor 工作（issue #1305）。
    private var isPanelVisible = false
    /// 待执行的合并刷新任务：一次剪贴板变化突发只触发一次全量刷新。
    private var refreshTask: Task<Void, Never>?

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

    /// 按当前搜索词过滤列表。
    ///
    /// - Note: 同步过滤，只在数据刷新等低频路径使用。
    ///   逐键输入请走 ``scheduleFilter()``。
    public func filterItems() {
        if searchText.isEmpty {
            items = allItems
        } else {
            items = Self.filter(allItems, keyword: searchText)
        }
    }

    /// 调度一次带防抖的搜索。
    ///
    /// 搜索词变化时取消上一个待执行任务，等待 200ms 无新输入后再扫描；
    /// 扫描在后台线程完成，结果写回前校验查询词仍是最新的一次，
    /// 避免慢的旧查询覆盖新查询的结果。
    public func scheduleFilter() {
        searchTask?.cancel()

        let keyword = searchText
        guard !keyword.isEmpty else {
            items = allItems
            return
        }

        let candidates = allItems
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            let matched = await Task.detached(priority: .userInitiated) {
                Self.filter(candidates, keyword: keyword)
            }.value

            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                // 查询词已变：丢弃过期结果。
                guard self.searchText == keyword else { return }
                self.items = matched
            }
        }
    }

    /// 按关键词过滤剪贴板条目。
    ///
    /// 纯函数，便于在后台线程调用与单元测试。
    nonisolated static func filter(
        _ items: [ClipboardHistoryItem],
        keyword: String
    ) -> [ClipboardHistoryItem] {
        // 空关键词直接返回全部：`String.contains("")` 恒为 false
        // （Foundation 的 `range(of:)` 对空串返回 nil），不能靠匹配来短路。
        guard !keyword.isEmpty else { return items }
        let lower = keyword.lowercased()
        return items.filter { $0.searchKeywords.contains(lower) }
    }
    
    /// 设置面板可见性。
    ///
    /// 剪贴板变化观察者在 `onBoot` 无条件注册，而面板只在活动栏条目激活时才安装。
    /// 隐藏时把刷新挡掉，避免每次系统级复制都在主 actor 上全量拉取 + 过滤 + 重发布
    /// （issue #1305）。重新可见时合并刷新一次，补上隐藏期间错过的变化。
    public func setPanelVisible(_ visible: Bool) {
        guard isPanelVisible != visible else { return }
        isPanelVisible = visible
        if visible {
            refresh()
        } else {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    /// 请求一次刷新：仅在面板可见时执行，并对突发通知做防抖合并。
    ///
    /// 多文件复制会按条目逐个广播通知（N 次），原先每次都全量重拉最多 5000 条。
    /// 这里取消上一个待执行任务，120ms 内的多次通知合并成一次 ``loadItems()``。
    /// 显式重载（删除 / 置顶 / 清空）仍直接走 ``loadItems()``。
    public func refresh() {
        guard isPanelVisible else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await self?.loadItems()
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
        let type = ClipboardItemType(rawValue: item.type)

        // 图片须先成功加载再清空剪贴板，否则缺失/损坏的 PNG 会清掉用户原有内容却写不进去（#243）。
        var image: NSImage?
        if type == .image {
            guard let loaded = NSImage(contentsOfFile: item.content) else { return false }
            image = loaded
        }

        pasteboard.clearContents()

        switch type {
        case .text:
            // 纯文本 + 富文本负载一起写回，接收方可按能力选择 RTF / HTML 恢复格式与链接。
            var succeeded = pasteboard.setString(item.content, forType: .string)
            if let rtf = item.richTextRTF {
                succeeded = pasteboard.setData(rtf, forType: .rtf) && succeeded
            }
            if let html = item.richTextHTML {
                succeeded = pasteboard.setString(html, forType: .html) && succeeded
            }
            return succeeded
        case .html, .color:
            return pasteboard.setString(item.content, forType: .string)
        case .file:
            return pasteboard.writeObjects([URL(fileURLWithPath: item.content) as NSPasteboardWriting])
        case .image:
            guard let image else { return false }
            return pasteboard.writeObjects([image])
        case .none:
            return pasteboard.setString(item.content, forType: .string)
        }
    }
}
