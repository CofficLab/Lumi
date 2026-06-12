import Foundation
import EditorKernel
import EditorService
import EditorService
import Combine
import LanguageServerProtocol

/// 调用层级提供者
@MainActor
public final class CallHierarchyProvider: ObservableObject, SuperEditorCallHierarchyProvider {
    
    private let lspService: LSPService
    private let prepareLifecycle = LSPRequestLifecycle()
    private let incomingLifecycle = LSPRequestLifecycle()
    private let outgoingLifecycle = LSPRequestLifecycle()
    private let requestPrepare: @Sendable (_ uri: String, _ line: Int, _ character: Int) async -> [LanguageServerProtocol.CallHierarchyItem]
    private let requestIncoming: @Sendable (_ item: LanguageServerProtocol.CallHierarchyItem) async -> [CallHierarchyIncomingCall]
    private let requestOutgoing: @Sendable (_ item: LanguageServerProtocol.CallHierarchyItem) async -> [CallHierarchyOutgoingCall]

    public init(
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
    
    @Published public var rootItem: EditorCallHierarchyItem?
    @Published public var incomingCalls: [EditorCallHierarchyCall] = []
    @Published public var outgoingCalls: [EditorCallHierarchyCall] = []
    @Published public var isLoading: Bool = false
    
    public var isAvailable: Bool { lspService.isAvailable }
    
    public func prepareCallHierarchy(uri: String, line: Int, character: Int) async {
        incomingLifecycle.invalidate()
        outgoingLifecycle.invalidate()
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
    
    public func fetchIncomingCalls(item: EditorCallHierarchyItem) async {
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
                guard rootItem == item else { return }
                incomingCalls = calls.compactMap { call in
                    EditorCallHierarchyCall(item: call.from, fromRanges: call.fromRanges)
                }
            }
        )
    }
    
    public func fetchOutgoingCalls(item: EditorCallHierarchyItem) async {
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
                guard rootItem == item else { return }
                outgoingCalls = calls.compactMap { call in
                    EditorCallHierarchyCall(item: call.to, fromRanges: call.fromRanges)
                }
            }
        )
    }
    
    public func clear() {
        prepareLifecycle.reset()
        incomingLifecycle.reset()
        outgoingLifecycle.reset()
        rootItem = nil
        incomingCalls = []
        outgoingCalls = []
        isLoading = false
    }

    public func reset() {
        prepareLifecycle.reset()
        incomingLifecycle.reset()
        outgoingLifecycle.reset()
    }
}
