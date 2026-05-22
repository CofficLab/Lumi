import SwiftUI

// MARK: - Sidebar Shell

/// Two-column settings layout: fixed-width sidebar + detail pane.
public struct AppSettingsSidebarShell<Sidebar: View, Detail: View>: View {
    private let sidebar: Sidebar
    private let detail: Detail

    public init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebar = sidebar()
        self.detail = detail()
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Sidebar column container with standard padding, width, and background.
public struct AppSettingsSidebarContainer<Content: View>: View {
    private let width: CGFloat
    private let content: Content

    public init(
        width: CGFloat = 220,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .frame(width: width)
            .background(.background.opacity(0.6))
    }
}

/// Detail pane with mystique background and content overlay.
public struct AppSettingsDetailPane<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            Color.clear
                .mystiqueBackground()
                .ignoresSafeArea()

            content
                .background(.background.opacity(0.8))
        }
    }
}

// MARK: - Sidebar Header

public struct AppSettingsSidebarHeader<Icon: View>: View {
    @LumiTheme private var theme

    private let name: String
    private let version: String?
    private let build: String?
    private let topSpacing: CGFloat
    private let bottomSpacing: CGFloat
    private let icon: Icon

    public init(
        name: String,
        version: String? = nil,
        build: String? = nil,
        topSpacing: CGFloat = 50,
        bottomSpacing: CGFloat = 16,
        @ViewBuilder icon: () -> Icon
    ) {
        self.name = name
        self.version = version
        self.build = build
        self.topSpacing = topSpacing
        self.bottomSpacing = bottomSpacing
        self.icon = icon()
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: topSpacing)

            icon

            Text(name)
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .center, spacing: 2) {
                if let version {
                    Text("v\(version)")
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }

                if let build {
                    Text("Build \(build)")
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer().frame(height: bottomSpacing)
        }
    }
}

// MARK: - Sidebar Item

/// Selectable sidebar row for settings navigation.
public struct AppSettingsSidebarItem: View {
    private let label: Label<Text, Image>
    private let isSelected: Bool
    private let action: () -> Void

    public init(
        label: Label<Text, Image>,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    public init(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.label = Label(title, systemImage: systemImage)
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                label
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appSurface(
            style: .custom(isSelected ? Color.secondary.opacity(0.25) : Color.clear),
            cornerRadius: 6
        )
    }
}

// MARK: - Expandable Group

/// Expandable sidebar section with chevron disclosure.
public struct AppSettingsExpandableSidebarGroup<Content: View>: View {
    @LumiTheme private var theme
    @Binding private var isExpanded: Bool

    private let title: String
    private let systemImage: String
    private let content: Content

    public init(
        isExpanded: Binding<Bool>,
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self._isExpanded = isExpanded
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .frame(width: 18)

                    Text(title)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.appMicroEmphasized)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(theme.textTertiary)
                }
                .font(.appCaption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
    }
}

// MARK: - Divider

public struct AppSettingsDivider: View {
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(theme.appDivider)
            .frame(height: 1)
    }
}
