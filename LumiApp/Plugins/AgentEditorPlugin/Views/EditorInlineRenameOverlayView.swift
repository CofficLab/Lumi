import SwiftUI

struct EditorInlineRenameOverlayView: View {
    @ObservedObject var state: EditorState
    @Binding var renameState: EditorInlineRenameState

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.primary)

                Text("Rename Symbol")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Spacer(minLength: 0)

                Button {
                    state.dismissInlineRename()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            TextField("New name", text: Binding(
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
                Text("Current: \(renameState.originalName)")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                if renameState.isLoadingPreview {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let summary = renameState.previewSummary {
                    Text(summary.summaryText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.primary)
                }
            }

            if let errorMessage = renameState.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.error)
                    .lineLimit(2)
            } else if let summary = renameState.previewSummary, !summary.fileLabels.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Files")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    ForEach(summary.fileLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            HStack {
                Button(renameState.canApply ? "Apply Rename" : "Preview Changes") {
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

                Button("Cancel") {
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
                        .stroke(AppUI.Color.semantic.textTertiary.opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        .onAppear {
            isInputFocused = true
        }
    }
}
