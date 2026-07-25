import EditorService
import SwiftUI
import LumiUI

/// 工作区符号搜索视图。
///
/// 用于展示一个可输入查询的工作区符号搜索面板。用户输入查询后，视图会对请求做轻量防抖，
/// 并调用 `WorkspaceSymbolProvider.searchSymbols(query:)` 获取 LSP `workspace/symbol` 结果。
/// 该视图负责搜索框、加载态、空状态和结果列表展示；具体 LSP 请求和结果转换由 Provider 负责。
public struct WorkspaceSymbolItemSearchView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var provider: WorkspaceSymbolProvider
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var searchTask: Task<Void, Never>?
    public let onSelect: (WorkspaceSymbolItem) -> Void

    public init(provider: WorkspaceSymbolProvider, onSelect: @escaping (WorkspaceSymbolItem) -> Void) {
        self.provider = provider
        self.onSelect = onSelect
    }
    
    public var filteredSymbols: [WorkspaceSymbolItem] {
        provider.filterLocalResults(query: query)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textSecondary)
                TextField("Search symbols...", text: $query)
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
            .padding(8)
            .appSurface(style: .subtle, cornerRadius: 0)
            Divider()
            if filteredSymbols.isEmpty && !provider.isSearching && !query.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: provider.searchError == nil ? "magnifyingglass" : "exclamationmark.triangle")
                        .font(.appLargeTitle)
                        .foregroundColor(theme.textSecondary)
                    Text(provider.searchError == nil ? "No matching symbols found" : "Workspace symbols currently unavailable")
                        .font(.appBody)
                        .foregroundColor(theme.textSecondary)
                    if let searchError = provider.searchError {
                        Text(searchError)
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
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
public struct WorkspaceSymbolRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let symbol: WorkspaceSymbolItem

    public init(symbol: WorkspaceSymbolItem) {
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol.iconSymbol)
                .font(.appCaption)
                .frame(width: 20)
                .foregroundColor(theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.name)
                    .font(.appCallout)
                    .foregroundColor(theme.textPrimary)
                if let container = symbol.containerName {
                    Text(container)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer()
            Text(symbol.kindDisplayName)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
