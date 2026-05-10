import SwiftUI

/// 工作区符号搜索视图。
///
/// 用于展示一个可输入查询的工作区符号搜索面板。用户输入查询后，视图会对请求做轻量防抖，
/// 并调用 `WorkspaceSymbolProvider.searchSymbols(query:)` 获取 LSP `workspace/symbol` 结果。
/// 该视图负责搜索框、加载态、空状态和结果列表展示；具体 LSP 请求和结果转换由 Provider 负责。
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
                VStack(spacing: 10) {
                    Image(systemName: provider.searchError == nil ? "magnifyingglass" : "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(provider.searchError == nil ? "未找到匹配的符号" : "工作区符号当前不可用")
                        .foregroundColor(.secondary)
                    if let searchError = provider.searchError {
                        Text(searchError)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
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

/// 工作区符号搜索结果行。
///
/// 展示单个 `WorkspaceSymbolItem` 的图标、名称、容器名称和符号类型。
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
