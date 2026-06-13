import SwiftUI
import EditorService
import LumiUI

/// 编辑器内联重命名悬浮层。
///
/// 负责承载符号重命名输入、预览状态和应用动作，是源码视图顶部的轻量级
/// rename 交互容器。
struct EditorInlineRenameOverlayView: View {
    @ObservedObject var state: EditorState
    @Binding var renameState: EditorInlineRenameState

    @FocusState private var isInputFocused: Bool

    init(state: EditorState, renameState: Binding<EditorInlineRenameState>) {
        self.state = state
        self._renameState = renameState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "7C6FFF"))

                Text(String(localized: "Rename Symbol", bundle: .module))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer(minLength: 0)

                Button {
                    state.dismissInlineRename()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            TextField(String(localized: "New name", bundle: .module), text: Binding(
                get: { renameState.draftName },
                set: { state.updateInlineRenameDraft($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .focused($isInputFocused)
            .onSubmit {
                if renameState.canApply {
                    state.applyInlineRename()
                } else {
                    Task { @MainActor in
                        await state.previewInlineRename()
                    }
                }
            }

            HStack(spacing: 8) {
                Text(String(localized: "Current: \(renameState.originalName)", bundle: .module))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))

                if renameState.isLoadingPreview {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let summary = renameState.previewSummary {
                    Text(summary.summaryText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "7C6FFF"))
                }
            }

            if let errorMessage = renameState.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "FF453A"))
                    .lineLimit(2)
            } else if let summary = renameState.previewSummary, !summary.fileLabels.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Files", bundle: .module))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    ForEach(summary.fileLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "98989E"))
                            .lineLimit(1)
                    }
                }
            }

            HStack {
                Button(renameState.canApply ? String(localized: "Apply Rename", bundle: .module) : String(localized: "Preview Changes", bundle: .module)) {
                    if renameState.canApply {
                        state.applyInlineRename()
                    } else {
                        Task { @MainActor in
                            await state.previewInlineRename()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(renameState.isLoadingPreview || (!renameState.canPreview && !renameState.canApply))

                Button(String(localized: "Cancel", bundle: .module)) {
                    state.dismissInlineRename()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "98989E").opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        .onAppear {
            isInputFocused = true
        }
    }
}
