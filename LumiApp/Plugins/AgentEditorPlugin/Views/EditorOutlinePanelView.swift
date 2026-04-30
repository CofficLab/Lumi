import SwiftUI
import MagicKit

struct EditorOutlinePanelView: View {
    @ObservedObject var state: EditorState
    @ObservedObject var provider: DocumentSymbolProvider
    var showsHeader: Bool = true
    var showsResizeHandle: Bool = true

    @State private var filterText: String = ""
    @State private var collapsedIDs = Set<String>()
    @State private var dragStartWidth: CGFloat?
    @State private var isResizeHandleHovering = false

    var body: some View {
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
            .frame(width: showsResizeHandle ? state.sidePanelWidth : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(alignment: .leading) {
                if showsResizeHandle {
                    Rectangle()
                        .fill(AppUI.Color.semantic.textTertiary.opacity(0.12))
                        .frame(width: 1)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Outline")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Spacer(minLength: 0)

                if provider.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button {
                    state.performPanelCommand(.closeOutline)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            TextField("Filter symbols", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if provider.symbols.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredSymbols) { item in
                        outlineRow(item, depth: 0)
                    }
                }
                .padding(8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 26, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(provider.isLoading ? "Loading Outline..." : "No Symbols")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
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
                    ? AppUI.Color.semantic.primary.opacity(0.08)
                    : .clear
            )
            .overlay(
                Rectangle()
                    .fill(
                        isResizeHandleHovering
                            ? AppUI.Color.semantic.primary.opacity(0.5)
                            : AppUI.Color.semantic.textTertiary.opacity(0.12)
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
                            dragStartWidth = state.sidePanelWidth
                        }
                        let baseWidth = dragStartWidth ?? state.sidePanelWidth
                        state.sidePanelWidth = CGFloat(min(max(baseWidth - value.translation.width, 240), 720))
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                        state.persistSidePanelWidth()
                    }
            )
    }

    private var filteredSymbols: [EditorDocumentSymbolItem] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return provider.symbols }
        return provider.symbols.compactMap { filtered($0, query: query.lowercased()) }
    }

    private var activePathIDs: Set<String> {
        Set(provider.symbols.compactMap { $0.activePath(for: state.cursorLine) }.flatMap { $0 })
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
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppUI.Color.semantic.textTertiary)
                                .frame(width: 12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(width: 12)
                    }

                    Button {
                        state.performOpenItem(.documentSymbol(item))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.iconSymbol)
                                .font(.system(size: 10))
                                .foregroundColor(activePathIDs.contains(item.id) ? AppUI.Color.semantic.primary : AppUI.Color.semantic.textSecondary)
                                .frame(width: 14)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 11, weight: activePathIDs.contains(item.id) ? .semibold : .regular))
                                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                                    .lineLimit(1)

                                Text("L\(item.line)" + (item.detail.map { " · \($0)" } ?? ""))
                                    .font(.system(size: 9))
                                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(activePathIDs.contains(item.id)
                                    ? AppUI.Color.semantic.primary.opacity(0.08)
                                    : Color.clear)
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
        )
    }

    private func toggleCollapse(_ id: String) {
        if collapsedIDs.contains(id) {
            collapsedIDs.remove(id)
        } else {
            collapsedIDs.insert(id)
        }
    }
}
