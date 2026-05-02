import SwiftUI

struct EditorPeekOverlayView: View {
    @ObservedObject var state: EditorState
    let presentation: EditorPeekPresentation

    @State private var selectedItemID: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 520, height: presentation.mode == .definition ? 220 : 280)
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
            selectedItemID = presentation.items.first?.id
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: presentation.mode == .definition ? "arrow.turn.down.right" : "arrow.triangle.branch")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.mode.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                Text(presentation.summary)
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                state.dismissPeek()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var content: some View {
        HStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(presentation.items) { item in
                        peekRow(item)
                    }
                }
                .padding(10)
            }
            .frame(width: presentation.mode == .definition ? 190 : 220)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                if let selectedItem {
                    HStack(spacing: 8) {
                        Text(selectedItem.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppUI.Color.semantic.textPrimary)
                            .lineLimit(1)

                        Text(selectedItem.badgeText)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppUI.Color.semantic.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppUI.Color.semantic.primary.opacity(0.12))
                            )
                    }

                    Text(selectedItem.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)

                    ScrollView {
                        Text(selectedItem.preview)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppUI.Color.semantic.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppUI.Color.semantic.textTertiary.opacity(0.06))
                            )
                    }
                } else {
                    Text(String(localized: "No preview available", table: "LumiEditor"))
                        .font(.system(size: 11))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        HStack {
            Text(String(localized: "\(presentation.items.count) items", table: "LumiEditor"))
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Spacer(minLength: 0)

            Button(String(localized: "Open", table: "LumiEditor")) {
                guard let selectedItem else { return }
                state.openPeekItem(selectedItem)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedItem == nil)

            Button(String(localized: "Close", table: "LumiEditor")) {
                state.dismissPeek()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var selectedItem: EditorPeekItem? {
        let preferredID = selectedItemID ?? presentation.items.first?.id
        return presentation.items.first { $0.id == preferredID }
    }

    private func peekRow(_ item: EditorPeekItem) -> some View {
        let isSelected = selectedItem?.id == item.id

        return Button {
            selectedItemID = item.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(item.badgeText)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppUI.Color.semantic.primary)
                }

                Text(item.subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .lineLimit(1)

                Text(item.preview)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? AppUI.Color.semantic.primary.opacity(0.12)
                            : AppUI.Color.semantic.textTertiary.opacity(0.05)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? AppUI.Color.semantic.primary.opacity(0.28) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
