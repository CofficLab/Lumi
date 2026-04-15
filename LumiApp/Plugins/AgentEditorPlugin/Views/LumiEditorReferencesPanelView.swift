import SwiftUI
import MagicKit

/// LSP References 结果面板
struct LumiEditorReferencesPanelView: View {
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
            Text("References (\(state.referenceResults.count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer(minLength: 0)

            Button {
                state.closeReferencePanel()
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
                ForEach(state.referenceResults) { item in
                    Button {
                        state.openReference(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(item.path):\(item.line):\(item.column)")
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
}
