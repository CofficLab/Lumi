import SwiftUI
import CodeEditTextView
import LanguageServerProtocol

/// 文档链接提供者
@MainActor
final class LumiDocumentLinkProvider: ObservableObject {
    
    private let lspService = LumiLSPService.shared
    
    @Published var links: [LumiDocumentLink] = []
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func requestLinks(uri: String) async {
        let serverLinks = await lspService.requestDocumentLinks(uri: uri)
        links = serverLinks.map { serverLink in
            LumiDocumentLink(
                range: serverLink.range,
                target: serverLink.target,
                tooltip: serverLink.tooltip,
                data: serverLink.data
            )
        }
    }
    
    func resolveLink(_ link: inout LumiDocumentLink) async {
        guard link.target == nil else { return }
        let lspLink = LanguageServerProtocol.DocumentLink(
            range: link.range, target: nil, tooltip: nil, data: link.data
        )
        if let resolved = await lspService.resolveDocumentLinkLSP(lspLink) {
            link.target = resolved.target
            link.tooltip = resolved.tooltip
        }
    }
    
    func clear() { links.removeAll() }
    
    func linkAtPosition(line: Int, character: Int) -> LumiDocumentLink? {
        let position = Position(line: line, character: character)
        return links.first { link in
            position >= link.range.start && position <= link.range.end
        }
    }
}

struct LumiDocumentLink: Identifiable, Equatable {
    let id = UUID()
    var range: LSPRange
    var target: DocumentUri?
    var tooltip: String?
    let data: LanguageServerProtocol.LSPAny?
    
    var isURL: Bool {
        guard let target else { return false }
        return target.hasPrefix("http://") || target.hasPrefix("https://")
    }
    
    var isFilePath: Bool {
        guard let target else { return false }
        return target.hasPrefix("file://")
    }
}

struct LumiDocumentLinkView: View {
    let text: String
    let link: LumiDocumentLink
    let onTap: () -> Void
    
    var body: some View {
        Text(text)
            .font(.system(size: NSFont.systemFontSize, design: .monospaced))
            .foregroundColor(.blue)
            .underline()
            .onTapGesture(perform: onTap)
            .help(link.tooltip ?? link.target ?? "")
    }
}
