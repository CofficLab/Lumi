import Foundation
import EditorKernel
import EditorService
import Combine
import EditorTextView
import LanguageServerProtocol

/// 文档链接提供者
@MainActor
public final class DocumentLinkProvider: ObservableObject {
    
    private let lspService: LSPService
    private let requestLifecycle = LSPRequestLifecycle()

    public init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }
    
    @Published var links: [EditorDocumentLink] = []
    
    public var isAvailable: Bool { lspService.isAvailable }
    
    public func requestLinks(uri: String) async {
        requestLifecycle.run(
            operation: { [lspService] in
                await lspService.requestDocumentLinks(uri: uri)
            },
            apply: { [weak self] serverLinks in
                guard let self else { return }
                links = serverLinks.map { serverLink in
                    EditorDocumentLink(
                        range: serverLink.range,
                        target: serverLink.target,
                        tooltip: serverLink.tooltip,
                        data: serverLink.data
                    )
                }
            }
        )
    }
    
    public func resolveLink(_ link: inout EditorDocumentLink) async {
        guard link.target == nil else { return }
        let lspLink = LanguageServerProtocol.DocumentLink(
            range: link.range, target: nil, tooltip: nil, data: link.data
        )
        if let resolved = await lspService.resolveDocumentLinkLSP(lspLink) {
            link.target = resolved.target
            link.tooltip = resolved.tooltip
        }
    }
    
    public func clear() {
        requestLifecycle.reset()
        links.removeAll()
    }

    public func reset() {
        requestLifecycle.reset()
    }
    
    public func linkAtPosition(line: Int, character: Int) -> EditorDocumentLink? {
        let position = Position(line: line, character: character)
        return links.first { link in
            position >= link.range.start && position <= link.range.end
        }
    }
}

public struct EditorDocumentLink: Identifiable, Equatable {
    public let id = UUID()
    public var range: LSPRange
    public var target: DocumentUri?
    public var tooltip: String?
    public let data: LanguageServerProtocol.LSPAny?
    
    public var isURL: Bool {
        guard let target else { return false }
        let normalizedTarget = target.lowercased()
        return normalizedTarget.hasPrefix("http://") || normalizedTarget.hasPrefix("https://")
    }
    
    public var isFilePath: Bool {
        guard let target else { return false }
        return target.lowercased().hasPrefix("file://")
    }
}
