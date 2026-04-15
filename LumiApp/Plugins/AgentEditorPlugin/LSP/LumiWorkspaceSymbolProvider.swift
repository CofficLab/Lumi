import SwiftUI
import Foundation
import LanguageServerProtocol

/// 工作区符号搜索提供者
@MainActor
final class LumiWorkspaceSymbolProvider: ObservableObject {
    
    private let lspService = LumiLSPService.shared
    
    @Published var symbols: [LumiWorkspaceSymbol] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String?
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func searchSymbols(query: String) async {
        isSearching = true
        searchError = nil
        
        guard let response = await lspService.requestWorkspaceSymbols(query: query) else {
            symbols = []; isSearching = false; return
        }
        
        switch response {
        case .optionA(let infos):
            symbols = infos.map { info in
                LumiWorkspaceSymbol(
                    name: info.name, kind: info.kind,
                    location: LumiSymbolLocation(uri: info.location.uri, range: info.location.range),
                    containerName: info.containerName, tags: info.tags, detail: nil, data: nil
                )
            }
        case .optionB(let wsSymbols):
            symbols = wsSymbols.compactMap { ws -> LumiWorkspaceSymbol? in
                guard let locOpt = ws.location else { return nil }
                switch locOpt {
                case .optionA(let loc):
                    return LumiWorkspaceSymbol(
                        name: ws.name, kind: ws.kind,
                        location: LumiSymbolLocation(uri: loc.uri, range: loc.range),
                        containerName: nil, tags: ws.tags, detail: nil, data: nil
                    )
                case .optionB(let identifier):
                    return LumiWorkspaceSymbol(
                        name: ws.name, kind: ws.kind,
                        location: LumiSymbolLocation(uri: identifier.uri, range: LSPRange(start: .zero, end: .zero)),
                        containerName: nil, tags: ws.tags, detail: nil, data: nil
                    )
                }
            }
        }
        isSearching = false
    }
    
    func clear() { symbols = []; isSearching = false; searchError = nil }
    
    func filterLocalResults(query: String) -> [LumiWorkspaceSymbol] {
        guard !query.isEmpty else { return symbols }
        let lowercased = query.lowercased()
        return symbols.filter { sym in
            sym.name.lowercased().contains(lowercased)
                || (sym.containerName?.lowercased().contains(lowercased) ?? false)
        }
    }
}

struct LumiWorkspaceSymbol: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let kind: SymbolKind
    let location: LumiSymbolLocation
    let containerName: String?
    let tags: [SymbolTag]?
    let detail: String?
    let data: LanguageServerProtocol.LSPAny?
    
    var kindDisplayName: String {
        switch kind {
        case .function: return "函数"
        case .method: return "方法"
        case .variable: return "变量"
        case .class: return "类"
        case .interface: return "接口"
        case .struct: return "结构体"
        case .enum: return "枚举"
        case .property: return "属性"
        case .constant: return "常量"
        case .field: return "字段"
        case .typeParameter: return "类型参数"
        default: return String(kind.rawValue)
        }
    }
    
    var iconSymbol: String {
        switch kind {
        case .function: return "f.cursive"
        case .method: return "cube"
        case .variable: return "text.word.spacing"
        case .class: return "square.stack"
        case .interface: return "circle.square"
        case .struct: return "box"
        case .enum: return "list.bullet"
        case .property: return "p.circle"
        case .constant: return "c.circle"
        case .field: return "f.circle"
        default: return "doc"
        }
    }
}

struct LumiSymbolLocation: Equatable {
    let uri: String
    let range: LSPRange
}

struct LumiWorkspaceSymbolSearchView: View {
    @ObservedObject var provider: LumiWorkspaceSymbolProvider
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    let onSelect: (LumiWorkspaceSymbol) -> Void
    
    var filteredSymbols: [LumiWorkspaceSymbol] {
        provider.filterLocalResults(query: query)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索符号...", text: $query)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        if !filteredSymbols.isEmpty { onSelect(filteredSymbols[selectedIndex]) }
                    }
                    .onChange(of: query) { _ in selectedIndex = 0 }
                if provider.isSearching { ProgressView().scaleEffect(0.7) }
            }
            .padding(8).background(Color(nsColor: .textBackgroundColor))
            Divider()
            if filteredSymbols.isEmpty && !provider.isSearching && !query.isEmpty {
                VStack {
                    Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundColor(.secondary)
                    Text("未找到匹配的符号").foregroundColor(.secondary).padding(.top, 8)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredSymbols.indices, id: \.self) { index in
                    WorkspaceSymbolRow(symbol: filteredSymbols[index])
                        .onTapGesture { onSelect(filteredSymbols[index]) }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 400, minHeight: 300, idealHeight: 500)
    }
}

struct WorkspaceSymbolRow: View {
    let symbol: LumiWorkspaceSymbol
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol.iconSymbol).font(.system(size: 12)).frame(width: 20).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.name).font(.system(size: 13))
                if let container = symbol.containerName {
                    Text(container).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(symbol.kindDisplayName).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .padding(.vertical, 4).padding(.horizontal, 8).contentShape(Rectangle())
    }
}
