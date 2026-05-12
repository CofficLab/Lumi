import SwiftUI
import EditorService
import LumiUI

/// 编辑器 peek 预览悬浮层。
///
/// 负责在当前编辑上下文中展示定义、引用等跳转结果的列表与内容预览，让用户无需离开当前文件就能浏览目标位置。
public struct EditorPeekOverlayView: View {
    @ObservedObject var state: EditorState
    let presentation: EditorPeekPresentation

    @State private var selectedItemID: String?

    public init(state: EditorState, presentation: EditorPeekPresentation) {
        self.state = state
        self.presentation = presentation
    }

    public var body: some View {
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
                        .stroke(Color(hex: "98989E").opacity(0.16), lineWidth: 1)
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
                .foregroundColor(Color(hex: "7C6FFF"))

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.mode.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Text(presentation.summary)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                state.dismissPeek()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                            .lineLimit(1)

                        Text(selectedItem.badgeText)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "7C6FFF"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "7C6FFF").opacity(0.12))
                            )
                    }

                    Text(selectedItem.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "98989E"))

                    ScrollView {
                        Text(selectedItem.preview)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "98989E").opacity(0.06))
                            )
                    }
                } else {
                    Text(String(localized: "No preview available"))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "98989E"))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        HStack {
            Text(String(localized: "\(presentation.items.count) items"))
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "98989E"))

            Spacer(minLength: 0)

            Button(String(localized: "Open")) {
                guard let selectedItem else { return }
                state.openPeekItem(selectedItem)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedItem == nil)

            Button(String(localized: "Close")) {
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
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(item.badgeText)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: "7C6FFF"))
                }

                Text(item.subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "98989E"))
                    .lineLimit(1)

                Text(item.preview)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? Color(hex: "7C6FFF").opacity(0.12)
                            : Color(hex: "98989E").opacity(0.05)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color(hex: "7C6FFF").opacity(0.28) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
