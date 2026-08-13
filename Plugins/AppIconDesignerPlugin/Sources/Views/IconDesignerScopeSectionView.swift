import SwiftUI

private typealias L = AppIconDesignerLocalization

/// Rail 中单个作用域分组的展开容器：标题 + 文档列表或空态/不可用提示。
struct IconDesignerScopeSectionView<Content: View>: View {
    @Binding var isExpanded: Bool
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let count: Int
    let isUnavailable: Bool
    let unavailableMessage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if isUnavailable {
                Label(unavailableMessage, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.leading, 20)
            } else {
                content()
            }
        } label: {
            header
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
