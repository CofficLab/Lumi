import SwiftUI
import Foundation
import LanguageServerProtocol

/// 调用层级提供者
@MainActor
final class CallHierarchyProvider: ObservableObject, SuperEditorCallHierarchyProvider {
    
    private let lspService: LSPService
    private let prepareLifecycle = LSPRequestLifecycle()
    private let incomingLifecycle = LSPRequestLifecycle()
    private let outgoingLifecycle = LSPRequestLifecycle()
    private let requestPrepare: @Sendable (_ uri: String, _ line: Int, _ character: Int) async -> [LanguageServerProtocol.CallHierarchyItem]
    private let requestIncoming: @Sendable (_ item: LanguageServerProtocol.CallHierarchyItem) async -> [CallHierarchyIncomingCall]
    private let requestOutgoing: @Sendable (_ item: LanguageServerProtocol.CallHierarchyItem) async -> [CallHierarchyOutgoingCall]

    init(
        lspService: LSPService = .shared,
        requestPrepare: (@Sendable (_ uri: String, _ line: Int, _ character: Int) async -> [LanguageServerProtocol.CallHierarchyItem])? = nil,
        requestIncoming: (@Sendable (_ item: LanguageServerProtocol.CallHierarchyItem) async -> [CallHierarchyIncomingCall])? = nil,
        requestOutgoing: (@Sendable (_ item: LanguageServerProtocol.CallHierarchyItem) async -> [CallHierarchyOutgoingCall])? = nil
    ) {
        self.lspService = lspService
        self.requestPrepare = requestPrepare ?? { [lspService] uri, line, character in
            await lspService.requestCallHierarchyPrepare(uri: uri, line: line, character: character)
        }
        self.requestIncoming = requestIncoming ?? { [lspService] item in
            await lspService.requestCallHierarchyIncomingCalls(item: item)
        }
        self.requestOutgoing = requestOutgoing ?? { [lspService] item in
            await lspService.requestCallHierarchyOutgoingCalls(item: item)
        }
    }
    
    @Published var rootItem: EditorCallHierarchyItem?
    @Published var incomingCalls: [EditorCallHierarchyCall] = []
    @Published var outgoingCalls: [EditorCallHierarchyCall] = []
    @Published var isLoading: Bool = false
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func prepareCallHierarchy(uri: String, line: Int, character: Int) async {
        isLoading = true
        incomingCalls = []
        outgoingCalls = []

        prepareLifecycle.run(
            operation: { [requestPrepare] in
                await requestPrepare(uri, line, character)
            },
            apply: { [weak self] items in
                guard let self else { return }
                guard let firstItem = items.first else {
                    rootItem = nil
                    incomingCalls = []
                    outgoingCalls = []
                    isLoading = false
                    return
                }

                let root = EditorCallHierarchyItem(item: firstItem)
                rootItem = root
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await fetchIncomingCalls(item: root)
                    await fetchOutgoingCalls(item: root)
                }
                isLoading = false
            }
        )
    }
    
    func fetchIncomingCalls(item: EditorCallHierarchyItem) async {
        // Convert back to LSP CallHierarchyItem for service call
        let lspItem = LanguageServerProtocol.CallHierarchyItem(
            name: item.name,
            kind: item.kind,
            tag: nil,
            detail: nil,
            uri: item.uri,
            range: item.range,
            selectionRange: item.selectionRange,
            data: item.data
        )
        incomingLifecycle.run(
            operation: { [requestIncoming] in
                await requestIncoming(lspItem)
            },
            apply: { [weak self] calls in
                guard let self else { return }
                incomingCalls = calls.compactMap { call in
                    EditorCallHierarchyCall(item: call.from, fromRanges: call.fromRanges)
                }
            }
        )
    }
    
    func fetchOutgoingCalls(item: EditorCallHierarchyItem) async {
        // Convert back to LSP CallHierarchyItem for service call
        let lspItem = LanguageServerProtocol.CallHierarchyItem(
            name: item.name,
            kind: item.kind,
            tag: nil,
            detail: nil,
            uri: item.uri,
            range: item.range,
            selectionRange: item.selectionRange,
            data: item.data
        )
        outgoingLifecycle.run(
            operation: { [requestOutgoing] in
                await requestOutgoing(lspItem)
            },
            apply: { [weak self] calls in
                guard let self else { return }
                outgoingCalls = calls.compactMap { call in
                    EditorCallHierarchyCall(item: call.to, fromRanges: call.fromRanges)
                }
            }
        )
    }
    
    func clear() {
        prepareLifecycle.reset()
        incomingLifecycle.reset()
        outgoingLifecycle.reset()
        rootItem = nil
        incomingCalls = []
        outgoingCalls = []
        isLoading = false
    }

    func reset() {
        prepareLifecycle.reset()
        incomingLifecycle.reset()
        outgoingLifecycle.reset()
    }
}

struct EditorCallHierarchyItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let kind: SymbolKind
    let uri: String
    let range: LSPRange
    let selectionRange: LSPRange
    let data: LanguageServerProtocol.LSPAny?
    
    init(item: LanguageServerProtocol.CallHierarchyItem) {
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

struct EditorCallHierarchyCall: Identifiable, Equatable {
    let id = UUID()
    let item: EditorCallHierarchyItem
    let fromRanges: [LSPRange]
    
    init(item: LanguageServerProtocol.CallHierarchyItem, fromRanges: [LSPRange]) {
        self.item = EditorCallHierarchyItem(item: item)
        self.fromRanges = fromRanges
    }
}

struct CallHierarchyTreeView: View {
    let calls: [EditorCallHierarchyCall]
    let direction: CallHierarchyDirection
    let onSelect: (EditorCallHierarchyItem) -> Void
    
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
    let item: EditorCallHierarchyItem
    let onSelect: (EditorCallHierarchyItem) -> Void
    
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
