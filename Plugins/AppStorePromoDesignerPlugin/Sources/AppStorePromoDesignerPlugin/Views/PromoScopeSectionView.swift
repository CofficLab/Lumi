import SwiftUI

/// Rail 中单个 scope 分组的展开容器：标题 + 任务列表或空态提示。
struct PromoScopeSectionView<EmptyContent: View>: View {
    @Binding var isExpanded: Bool
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let count: Int
    let isUnavailable: Bool
    let unavailableMessage: String
    let emptyMessage: String
    let emptyContent: () -> EmptyContent

    // MARK: - 初始化

    init(
        isExpanded: Binding<Bool>,
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        count: Int,
        isUnavailable: Bool,
        unavailableMessage: String,
        emptyMessage: String,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent
    ) {
        self._isExpanded = isExpanded
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.isUnavailable = isUnavailable
        self.unavailableMessage = unavailableMessage
        self.emptyMessage = emptyMessage
        self.emptyContent = emptyContent
    }

    // MARK: - Body

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if isUnavailable {
                PromoScopeEmptyView(message: unavailableMessage)
            } else {
                emptyContent()
            }
        } label: {
            header
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - 预览

#Preview {
    StatefulPreviewWrapper(true) { binding in
        PromoScopeSectionView(
            isExpanded: binding,
            icon: "folder",
            iconColor: .accentColor,
            title: "In Project",
            subtitle: "· MyApp",
            count: 0,
            isUnavailable: false,
            unavailableMessage: "Open a project to enable project-local storage.",
            emptyMessage: "Ask the Agent to create a promotional artwork task."
        ) {
            PromoScopeEmptyView(
                message: "Ask the Agent to create a promotional artwork task."
            )
        }
    }
    .padding()
    .frame(width: 300)
    .background(Color(nsColor: .controlBackgroundColor))
}

/// 仅用于预览：为绑定提供可写状态。
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}