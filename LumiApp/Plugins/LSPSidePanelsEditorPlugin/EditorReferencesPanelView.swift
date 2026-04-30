import SwiftUI
import MagicKit

/// LSP References 结果面板
struct EditorReferencesPanelView: View {
    @ObservedObject var state: EditorState
    @State private var dragStartWidth: CGFloat?
    @State private var isResizeHandleHovering = false

    var body: some View {
        HStack(spacing: 0) {
            resizeHandle

            VStack(spacing: 0) {
                header
                GlassDivider()
                content
            }
            .frame(width: state.sidePanelWidth)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                Rectangle()
                    .fill(AppUI.Color.semantic.textTertiary.opacity(0.12))
                    .frame(width: 1),
                alignment: .leading
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(String(localized: "References", table: "LumiEditor") + " (\(state.panelState.referenceResults.count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer(minLength: 0)

            Button {
                state.performPanelCommand(.closeReferences)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if !state.semanticProblems.isEmpty {
                    semanticContextBanner
                }
                ForEach(state.panelState.referenceResults) { item in
                    Button {
                        state.performOpenItem(
                            .reference(
                                .init(
                                    url: item.url,
                                    line: item.line,
                                    column: item.column,
                                    path: item.path,
                                    preview: item.preview
                                )
                            )
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "Location", table: "LumiEditor") + ": \(item.path):\(item.line):\(item.column)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppUI.Color.semantic.textPrimary)
                                .lineLimit(1)

                            if !item.preview.isEmpty {
                                Text(item.preview)
                                    .font(.system(size: 10))
                                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppUI.Color.semantic.textTertiary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var semanticContextBanner: some View {
        if let issue = state.semanticProblems.first(where: { $0.severity != .info }) ?? state.semanticProblems.first {
            let color = color(for: issue.severity)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon(for: issue.severity))
                        .foregroundColor(color)
                    Text(issue.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                    Spacer(minLength: 0)
                    Button("重新解析") {
                        state.resyncXcodeBuildContext()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.primary)
                    .disabled(state.isResyncingXcodeBuildContext)
                }

                Text(issue.message)
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.32), lineWidth: 1)
            )
        }
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

    private func icon(for severity: XcodeSemanticAvailability.ReasonSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }

    private func color(for severity: XcodeSemanticAvailability.ReasonSeverity) -> Color {
        switch severity {
        case .info:
            return AppUI.Color.semantic.primary
        case .warning:
            return AppUI.Color.semantic.warning
        case .error:
            return AppUI.Color.semantic.error
        }
    }
}
