import SwiftUI
import MagicKit
import LanguageServerProtocol

/// LSP Problems 面板（当前文件）
struct LumiEditorProblemsPanelView: View {
    @ObservedObject var state: LumiEditorState

    var body: some View {
        VStack(spacing: 0) {
            header
            GlassDivider()
            content
        }
        .frame(width: 360)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            Rectangle()
                .fill(AppUI.Color.semantic.textTertiary.opacity(0.12))
                .frame(width: 1),
            alignment: .leading
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(String(localized: "Problems", table: "LumiEditor") + " (\(state.problemDiagnostics.count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer(minLength: 0)

            Button {
                state.closeProblemsPanel()
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

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if state.problemDiagnostics.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(state.problemDiagnostics.enumerated()), id: \.offset) { _, diag in
                        Button {
                            state.openProblem(diag)
                        } label: {
                            row(for: diag)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(8)
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

    private func row(for diag: Diagnostic) -> some View {
        let (icon, color) = iconAndColor(for: diag.severity)
        let line = Int(diag.range.start.line) + 1
        let column = Int(diag.range.start.character) + 1

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
                .fill(AppUI.Color.semantic.textTertiary.opacity(0.06))
        )
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
    LumiEditorProblemsPanelView(state: LumiEditorState())
        .inRootView()
}
