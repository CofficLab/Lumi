import EditorService
import LumiUI
import SwiftUI
import LumiKernel

public struct EditorOutlinePanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var service: EditorService
    @ObservedObject var provider: DocumentSymbolProvider
    public var showsHeader: Bool = true
    public var showsResizeHandle: Bool = true

    private static let defaultWidth: CGFloat = 360
    private static let minWidth: CGFloat = 240
    private static let maxWidth: CGFloat = 720

    @State private var filterText: String = ""
    @State private var collapsedIDs = Set<String>()
    @State private var panelWidth: CGFloat = defaultWidth
    @State private var dragStartWidth: CGFloat?
    @State private var isResizeHandleHovering = false

    public var body: some View {
        HStack(spacing: 0) {
            if showsResizeHandle {
                resizeHandle
            }

            VStack(spacing: 0) {
                if showsHeader {
                    header
                    GlassDivider()
                }
                content
            }
            .frame(width: showsResizeHandle ? panelWidth : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.surface)
            .overlay(alignment: .leading) {
                if showsResizeHandle {
                    Rectangle()
                        .fill(theme.textTertiary.opacity(0.12))
                        .frame(width: 1)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(LumiPluginLocalization.string("Outline", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer(minLength: 0)

                if provider.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button {
                    service.panel.performPanelCommand(.closeOutline)
                } label: {
                    Image(systemName: "xmark")
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            TextField(LumiPluginLocalization.string("Filter symbols", bundle: .module), text: $filterText)
                .textFieldStyle(.roundedBorder)
                .font(.appMicro)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if provider.symbols.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredSymbols) { item in
                            outlineRow(item, depth: 0)
                        }
                    }
                    .padding(8)
                }
                .onAppear {
                    syncActiveSymbolPresentation(using: proxy)
                }
                .onChange(of: service.editing.cursorLine) { _, _ in
                    syncActiveSymbolPresentation(using: proxy)
                }
                .onChange(of: provider.symbols.map(\.id)) { _, _ in
                    syncActiveSymbolPresentation(using: proxy)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.indent")
                .font(.appTitle)
                .foregroundColor(theme.textTertiary)

            Text(provider.isLoading ? LumiPluginLocalization.string("Loading Outline...", bundle: .module) : LumiPluginLocalization.string("No Symbols", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .background(
                isResizeHandleHovering
                    ? theme.primary.opacity(0.08)
                    : .clear
            )
            .overlay(
                Rectangle()
                    .fill(
                        isResizeHandleHovering
                            ? theme.primary.opacity(0.5)
                            : theme.textTertiary.opacity(0.12)
                    )
                    .frame(width: 1)
            )
            .onHover { isHovering in
                isResizeHandleHovering = isHovering
                if isHovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartWidth == nil {
                            dragStartWidth = panelWidth
                        }
                        let baseWidth = dragStartWidth ?? panelWidth
                        panelWidth = CGFloat(min(max(baseWidth - value.translation.width, Self.minWidth), Self.maxWidth))
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
    }

    private var filteredSymbols: [EditorDocumentSymbolItem] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return provider.symbols }
        return provider.symbols.compactMap { filtered($0, query: query.lowercased()) }
    }

    private var activePathIDs: Set<String> {
        Set(provider.symbols.compactMap { $0.activePath(for: service.editing.cursorLine) }.flatMap { $0 })
    }

    private func filtered(_ item: EditorDocumentSymbolItem, query: String) -> EditorDocumentSymbolItem? {
        let filteredChildren = item.children.compactMap { filtered($0, query: query) }
        let matchesSelf = item.name.lowercased().contains(query)
            || (item.detail?.lowercased().contains(query) ?? false)
        guard matchesSelf || !filteredChildren.isEmpty else { return nil }
        return EditorDocumentSymbolItem(
            id: item.id,
            name: item.name,
            detail: item.detail,
            kind: item.kind,
            range: item.range,
            selectionRange: item.selectionRange,
            children: filteredChildren
        )
    }

    private func outlineRow(_ item: EditorDocumentSymbolItem, depth: Int) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if !item.children.isEmpty {
                        Button {
                            toggleCollapse(item.id)
                        } label: {
                            Image(systemName: collapsedIDs.contains(item.id) ? "chevron.right" : "chevron.down")
                                .font(.appMicroEmphasized)
                                .foregroundColor(theme.textTertiary)
                                .frame(width: 12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(width: 12)
                    }

                    Button {
                        service.navigation.performOpenItem(.documentSymbol(item))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.iconSymbol)
                                .font(.appMicro)
                                .foregroundColor(activePathIDs.contains(item.id) ? theme.primary : theme.textSecondary)
                                .frame(width: 14)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(activePathIDs.contains(item.id) ? .appMicroEmphasized : .appMicro)
                                    .foregroundColor(theme.textPrimary)
                                    .lineLimit(1)

                                Text("L\(item.line)" + (item.detail.map { " · \($0)" } ?? ""))
                                    .font(.appMicro)
                                    .foregroundColor(theme.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .appSurface(
                            style: .custom(activePathIDs.contains(item.id) ? theme.primary.opacity(0.08) : Color.clear),
                            cornerRadius: 6
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, CGFloat(depth) * 14)

                if !item.children.isEmpty && !collapsedIDs.contains(item.id) {
                    ForEach(item.children) { child in
                        outlineRow(child, depth: depth + 1)
                    }
                }
            }
            .id(item.id)
        )
    }

    private func toggleCollapse(_ id: String) {
        if collapsedIDs.contains(id) {
            collapsedIDs.remove(id)
        } else {
            collapsedIDs.insert(id)
        }
    }

    private func syncActiveSymbolPresentation(using proxy: ScrollViewProxy) {
        let activePathIDs = provider.activePathIDs(for: service.editing.cursorLine)
        guard !activePathIDs.isEmpty else { return }

        let ancestorIDs = provider.activeAncestorIDs(for: service.editing.cursorLine)
        collapsedIDs.subtract(ancestorIDs)

        guard filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let activeSymbolID = activePathIDs.last
        else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(activeSymbolID, anchor: .center)
            }
        }
    }
}
