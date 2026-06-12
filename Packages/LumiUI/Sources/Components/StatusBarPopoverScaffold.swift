import SwiftUI

public struct StatusBarPopoverScaffold<HeaderAccessory: View, Content: View, Footer: View>: View {
    @LumiTheme private var theme

    private let title: String
    private let systemImage: String?
    private let subtitle: String?
    private let showsHeaderDivider: Bool
    private let headerAccessory: HeaderAccessory
    private let content: Content
    private let footer: Footer

    public init(
        title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        showsHeaderDivider: Bool = true,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.showsHeaderDivider = showsHeaderDivider
        self.headerAccessory = headerAccessory()
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
            header

            if showsHeaderDivider {
                GlassDivider()
            }

            content
                .font(.appCaption)
                .foregroundColor(theme.textPrimary)
                .tint(theme.primary)

            footer
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppUI.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.appCallout)
                    .foregroundColor(theme.primary)
                    .frame(width: 18)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appCallout)
                    .foregroundColor(theme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                }
            }

            Spacer(minLength: AppUI.Spacing.sm)

            headerAccessory
        }
    }
}

public extension StatusBarPopoverScaffold where HeaderAccessory == EmptyView, Footer == EmptyView {
    init(
        title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        showsHeaderDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            subtitle: subtitle,
            showsHeaderDivider: showsHeaderDivider,
            headerAccessory: { EmptyView() },
            content: content,
            footer: { EmptyView() }
        )
    }
}

public extension StatusBarPopoverScaffold where Footer == EmptyView {
    init(
        title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        showsHeaderDivider: Bool = true,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            subtitle: subtitle,
            showsHeaderDivider: showsHeaderDivider,
            headerAccessory: headerAccessory,
            content: content,
            footer: { EmptyView() }
        )
    }
}

public struct StatusBarPopoverInfoRow: View {
    @LumiTheme private var theme

    private let label: String
    private let value: String
    private let valueColor: Color?
    private let labelWidth: CGFloat

    public init(
        label: String,
        value: String,
        valueColor: Color? = nil,
        labelWidth: CGFloat = 76
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.labelWidth = labelWidth
    }

    public var body: some View {
        HStack(spacing: AppUI.Spacing.sm) {
            Text(label)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .frame(width: labelWidth, alignment: .leading)

            Text(value)
                .font(.appCaption)
                .foregroundColor(valueColor ?? theme.textPrimary)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }
}

public struct StatusBarPopoverMetricBadge: View {
    @LumiTheme private var theme

    private let label: String
    private let value: String
    private let tint: Color?

    public init(label: String, value: String, tint: Color? = nil) {
        self.label = label
        self.value = value
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.appCaptionEmphasized)
                .foregroundColor(tint ?? theme.textPrimary)
                .monospacedDigit()

            Text(label)
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
        }
    }
}

