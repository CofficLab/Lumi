import SwiftUI
import MagicKit
import LanguageServerProtocol

/// LSP Problems 面板（当前文件）
struct ProblemsPanelView: View {
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
            Text(String(localized: "Problems", table: "LumiEditor") + " (\(state.panelState.problemDiagnostics.count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer(minLength: 0)

            Button {
                state.performPanelCommand(.closeProblems)
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if state.panelState.problemDiagnostics.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(state.panelState.problemDiagnostics.enumerated()), id: \.offset) { index, diag in
                            Button {
                                state.performOpenItem(.problem(diag))
                            } label: {
                                row(for: diag)
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                }
                .padding(8)
            }
            .onAppear {
                scrollToSelectedProblem(with: proxy)
            }
            .onChange(of: state.panelState.selectedProblemDiagnostic) { _, _ in
                scrollToSelectedProblem(with: proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 26, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "No Problems", table: "LumiEditor"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
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

    private func row(for diag: Diagnostic) -> some View {
        let (icon, color) = iconAndColor(for: diag.severity)
        let line = Int(diag.range.start.line) + 1
        let column = Int(diag.range.start.character) + 1
        let isSelected = state.panelState.selectedProblemDiagnostic == diag

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)

                Text("\(state.relativeFilePath):\(line):\(column)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let source = diag.source, !source.isEmpty {
                    Text(source)
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .lineLimit(1)
                }
            }

            Text(diag.message)
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? color.opacity(0.16)
                        : AppUI.Color.semantic.textTertiary.opacity(0.06)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isSelected
                        ? color.opacity(0.55)
                        : .clear,
                    lineWidth: 1
                )
        )
    }

    private func scrollToSelectedProblem(with proxy: ScrollViewProxy) {
        guard let selected = state.panelState.selectedProblemDiagnostic,
              let index = state.panelState.problemDiagnostics.firstIndex(of: selected) else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }

    private func iconAndColor(for severity: DiagnosticSeverity?) -> (String, SwiftUI.Color) {
        switch severity {
        case .error:
            return ("xmark.circle.fill", AppUI.Color.semantic.error)
        case .warning:
            return ("exclamationmark.triangle.fill", AppUI.Color.semantic.warning)
        case .information:
            return ("info.circle.fill", AppUI.Color.semantic.primary)
        case .hint:
            return ("lightbulb.fill", AppUI.Color.semantic.textSecondary)
        case .none:
            return ("questionmark.circle", AppUI.Color.semantic.textTertiary)
        }
    }
}

#Preview {
    ProblemsPanelView(state: EditorState())
        .inRootView()
}
