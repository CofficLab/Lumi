import SwiftUI
import Foundation
import LanguageServerProtocol

/// 调用层级提供者
@MainActor
final class LumiCallHierarchyProvider: ObservableObject {
    
    private let lspService = LumiLSPService.shared
    
    @Published var rootItem: LumiCallHierarchyItem?
    @Published var incomingCalls: [LumiCallHierarchyCall] = []
    @Published var outgoingCalls: [LumiCallHierarchyCall] = []
    @Published var isLoading: Bool = false
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func prepareCallHierarchy(uri: String, line: Int, character: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        let items = await lspService.requestCallHierarchyPrepare(uri: uri, line: line, character: character)
        guard let firstItem = items.first else {
            rootItem = nil; incomingCalls = []; outgoingCalls = []
            return
        }
        rootItem = LumiCallHierarchyItem(item: firstItem)
        await fetchIncomingCalls(item: firstItem)
        await fetchOutgoingCalls(item: firstItem)
    }
    
    func fetchIncomingCalls(item: CallHierarchyItem) async {
        let calls = await lspService.requestCallHierarchyIncomingCalls(item: item)
        incomingCalls = calls.compactMap { call in
            LumiCallHierarchyCall(item: call.from, fromRanges: call.fromRanges)
        }
    }
    
    func fetchOutgoingCalls(item: CallHierarchyItem) async {
        let calls = await lspService.requestCallHierarchyOutgoingCalls(item: item)
        outgoingCalls = calls.compactMap { call in
            LumiCallHierarchyCall(item: call.to, fromRanges: call.fromRanges)
        }
    }
    
    func clear() {
        rootItem = nil; incomingCalls = []; outgoingCalls = []; isLoading = false
    }
}

struct LumiCallHierarchyItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let kind: SymbolKind
    let uri: String
    let range: LSPRange
    let selectionRange: LSPRange
    let data: LanguageServerProtocol.LSPAny?
    
    init(item: CallHierarchyItem) {
        self.name = item.name
        self.kind = item.kind
        self.uri = item.uri
        self.range = item.range
        self.selectionRange = item.selectionRange
        self.data = item.data
    }
    
    var kindDisplayName: String {
        switch kind {
        case .function: return "函数"
        case .method: return "方法"
        case .constructor: return "构造函数"
        case .class: return "类"
        case .interface: return "接口"
        case .struct: return "结构体"
        case .enum: return "枚举"
        case .enumMember: return "枚举成员"
        default: return String(kind.rawValue)
        }
    }
    
    var iconSymbol: String {
        switch kind {
        case .function: return "f.cursive"
        case .method: return "cube"
        case .constructor: return "plus.square"
        case .class: return "square.stack"
        case .interface: return "circle.square"
        case .struct: return "box"
        case .enum: return "list.bullet"
        case .enumMember: return "bullet"
        default: return "doc"
        }
    }
}

struct LumiCallHierarchyCall: Identifiable, Equatable {
    let id = UUID()
    let item: LumiCallHierarchyItem
    let fromRanges: [LSPRange]
    
    init(item: CallHierarchyItem, fromRanges: [LSPRange]) {
        self.item = LumiCallHierarchyItem(item: item)
        self.fromRanges = fromRanges
    }
}

struct LumiCallHierarchyTreeView: View {
    let calls: [LumiCallHierarchyCall]
    let direction: CallHierarchyDirection
    let onSelect: (LumiCallHierarchyItem) -> Void
    
    enum CallHierarchyDirection {
        case incoming, outgoing
        var title: String { self == .incoming ? "调用者" : "被调用者" }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(direction.title).font(.headline).padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
            if calls.isEmpty {
                Text("无\(direction.title)").font(.subheadline).foregroundColor(.secondary).padding()
            } else {
                List(calls) { call in
                    CallHierarchyRowView(item: call.item, onSelect: onSelect)
                }
            }
        }
    }
}

struct CallHierarchyRowView: View {
    let item: LumiCallHierarchyItem
    let onSelect: (LumiCallHierarchyItem) -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.iconSymbol).font(.system(size: 12)).frame(width: 16).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 13))
                Text(item.kindDisplayName).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4).padding(.horizontal, 8).contentShape(Rectangle())
        .onTapGesture { onSelect(item) }
    }
}
