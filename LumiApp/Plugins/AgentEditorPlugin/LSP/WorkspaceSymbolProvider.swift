import SwiftUI
import Foundation
import LanguageServerProtocol

/// 工作区符号搜索提供者
@MainActor
final class WorkspaceSymbolProvider: ObservableObject {
    
    private let lspService = LSPService.shared
    
    @Published var symbols: [WorkspaceSymbolItem] = []
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
                WorkspaceSymbolItem(
                    name: info.name, kind: info.kind,
                    location: SymbolLocation(uri: info.location.uri, range: info.location.range),
                    containerName: info.containerName, tags: info.tags, detail: nil, data: nil
                )
            }
        case .optionB(let wsSymbols):
            symbols = wsSymbols.compactMap { ws -> WorkspaceSymbolItem? in
                guard let locOpt = ws.location else { return nil }
                switch locOpt {
                case .optionA(let loc):
                    return WorkspaceSymbolItem(
                        name: ws.name, kind: ws.kind,
                        location: SymbolLocation(uri: loc.uri, range: loc.range),
                        containerName: nil, tags: ws.tags, detail: nil, data: nil
                    )
                case .optionB(let identifier):
                    return WorkspaceSymbolItem(
                        name: ws.name, kind: ws.kind,
                        location: SymbolLocation(uri: identifier.uri, range: LSPRange(start: .zero, end: .zero)),
                        containerName: nil, tags: ws.tags, detail: nil, data: nil
                    )
                }
            }
        }
        isSearching = false
    }
    
    func clear() { symbols = []; isSearching = false; searchError = nil }
    
    func filterLocalResults(query: String) -> [WorkspaceSymbolItem] {
        guard !query.isEmpty else { return symbols }
        let lowercased = query.lowercased()
        return symbols.filter { sym in
            sym.name.lowercased().contains(lowercased)
                || (sym.containerName?.lowercased().contains(lowercased) ?? false)
        }
    }
}

struct WorkspaceSymbolItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let kind: SymbolKind
    let location: SymbolLocation
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

struct SymbolLocation: Equatable {
    let uri: String
    let range: LSPRange
}

struct WorkspaceSymbolItemSearchView: View {
    @ObservedObject var provider: WorkspaceSymbolProvider
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var searchTask: Task<Void, Never>?
    let onSelect: (WorkspaceSymbolItem) -> Void
    
    var filteredSymbols: [WorkspaceSymbolItem] {
        provider.filterLocalResults(query: query)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索符号...", text: $query)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        guard !filteredSymbols.isEmpty else { return }
                        let index = min(max(selectedIndex, 0), filteredSymbols.count - 1)
                        onSelect(filteredSymbols[index])
                    }
                    .onChange(of: query) { _, newValue in
                        selectedIndex = 0
                        searchTask?.cancel()

                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            provider.clear()
                            return
                        }

                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(220))
                            guard !Task.isCancelled else { return }
                            await provider.searchSymbols(query: trimmed)
                        }
                    }
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
        .onDisappear {
            searchTask?.cancel()
        }
    }
}

struct WorkspaceSymbolRow: View {
    let symbol: WorkspaceSymbolItem
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
