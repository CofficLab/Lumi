import LumiUI
import SwiftUI

/// 可选择、可展开说明的 AskUser 选项行。
///
/// 选项主体负责提交答案，右侧的展开按钮只负责显示完整说明，避免
/// “查看详情”和“选择该项”发生冲突。
struct AskUserOptionRow: View {
    @LumiTheme private var theme

    let option: AskUserOption
    let selectedAnswer: String?
    let responded: Bool
    let onSelect: (String) -> Void

    @State private var isExpanded: Bool

    init(
        option: AskUserOption,
        selectedAnswer: String?,
        responded: Bool,
        onSelect: @escaping (String) -> Void
    ) {
        self.option = option
        self.selectedAnswer = selectedAnswer
        self.responded = responded
        self.onSelect = onSelect
        _isExpanded = State(initialValue: selectedAnswer == option.label)
    }

    private var isSelected: Bool {
        selectedAnswer == option.label
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                onSelect(option.label)
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.label)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textPrimary)

                        if let description = option.description {
                            Text(description)
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(isExpanded ? nil : 2)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? theme.success : theme.textSecondary)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(responded)

            if option.description != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "收起完整说明" : "展开完整说明")
                .accessibilityLabel(isExpanded ? "收起完整说明" : "展开完整说明")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? theme.success.opacity(0.12) : theme.elevatedSurface)
        )
        .opacity(responded && !isSelected ? 0.8 : 1)
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded = true
                }
            }
        }
    }
}
