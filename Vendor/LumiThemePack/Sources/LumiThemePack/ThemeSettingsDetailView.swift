import LumiUI
import ProviderTheme
import SwiftUI

private typealias AppThemeValue = ProviderTheme.LumiTheme
private typealias AppThemeAppearanceKind = ProviderTheme.ThemeAppearanceKind

/// 外观设置详情：使用新版 ProviderTheme，提供外观筛选、双栏浏览、
/// 主题预览与显式应用状态。
///
/// 不提供主题搜索：主题目录是固定枚举，条目数量有限，
/// 搜索栏带来的收益不足以抵消它占用的首屏空间。
@MainActor
public struct ThemeSettingsDetailView: View {
    let theme: any ThemeProviding

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var themeObservation: ThemeSettingsObservationModel
    @LumiUI.LumiTheme private var uiTheme: any LumiUI.LumiUITheme
    @State private var selectedID: String?
    @State private var appearanceFilter: ThemeAppearanceFilter = .all
    @State private var isPreviewPresented = false

    public init(theme: any ThemeProviding) {
        self.theme = theme
        _themeObservation = StateObject(wrappedValue: ThemeSettingsObservationModel(theme: theme))
    }

    private var filteredThemes: [AppThemeValue] {
        ThemeFilter.filter(themes: theme.themes, filter: appearanceFilter)
    }

    private var selectedTheme: AppThemeValue? {
        if let selectedID, let item = theme.themes.first(where: { $0.id == selectedID }) {
            return item
        }
        return filteredThemes.first ?? theme.themes.first
    }

    public var body: some View {
        Group {
            #if os(iOS)
            iosBody
            #else
            if horizontalSizeClass == .compact {
                compactBody
            } else {
                regularBody
            }
            #endif
        }
        .onAppear { selectedID = theme.selectedThemeId ?? selectedTheme?.id }
        .onReceive(themeObservation.$revision) { _ in selectedID = theme.selectedThemeId }
        .onChange(of: filteredThemes.map(\.id)) { ids in
            guard let selectedID, ids.contains(selectedID) else {
                self.selectedID = ids.first
                return
            }
        }
    }

    // MARK: - iOS

#if os(iOS)
    /// iOS 外观页：主题列表，点击即应用并打勾。
    ///
    /// 桌面端的双栏「列表 + 预览面板」在 iPhone 上退化成卡片拼贴，
    /// 因此 iOS 改为「列表 + 对勾 + 预览弹层」的原生表达：
    /// 筛选降级为导航栏菜单，预览收敛为可关闭的 sheet。
    @ViewBuilder
    private var iosBody: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                AppSettingSection(
                    title: String(
                        format: LumiThemePackLocalization.string("%lld Themes"),
                        Int64(theme.themes.count)
                    )
                ) {
                    ForEach(filteredThemes) { item in
                        AppSettingCheckmarkRow(
                            item.displayName,
                            description: item.description,
                            isSelected: theme.selectedThemeId == item.id,
                            leadingColor: item.palette.accentPrimary.color(),
                            action: { try? theme.selectTheme(id: item.id) }
                        )
                    }

                    if filteredThemes.isEmpty {
                        AppEmptyState(
                            icon: "paintpalette",
                            title: LumiThemePackLocalization.string("No Themes Found")
                        )
                        .padding(.vertical, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ThemeAppearanceFilter.allCases) { filter in
                        Button {
                            appearanceFilter = filter
                        } label: {
                            if filter == appearanceFilter {
                                Label(filter.title, systemImage: "checkmark")
                            } else {
                                Text(filter.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(LumiThemePackLocalization.string("Filter"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPreviewPresented = true
                } label: {
                    Image(systemName: "eye")
                }
                .accessibilityLabel(LumiThemePackLocalization.string("Preview"))
                .disabled(selectedTheme == nil)
            }
        }
        .sheet(isPresented: $isPreviewPresented) {
            if let selectedTheme {
                IOSThemePreviewSheet(theme: selectedTheme)
            }
        }
    }
#endif

    private var compactBody: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                headerStats
                themeFilterControls
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                AppDivider()

                LazyVStack(spacing: 4) {
                    ForEach(filteredThemes) { item in
                        NavigationLink {
                            ThemePreviewPane(
                                item: item,
                                isActive: theme.selectedThemeId == item.id,
                                containerBackground: uiTheme.surface,
                                onApply: { try? theme.selectTheme(id: item.id) }
                            )
                            .navigationTitle(item.displayName)
#if os(iOS)
                            .navigationBarTitleDisplayMode(.inline)
#endif
                        } label: {
                            themeListRowContent(item)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }

                    if filteredThemes.isEmpty {
                        AppEmptyState(icon: "paintpalette", title: LumiThemePackLocalization.string("No Themes Found"))
                            .padding(.vertical, 32)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 常规宽度（macOS 桌面）：左列表 + 右预览的贴边布局。
    ///
    /// - 主体内容贴到窗口左右与底边，没有外框描边，也没有底部留白；
    /// - 头部行自行保留 24 的左右内边距，不贴到窗口边缘；
    /// - 头部行与主体之间用一条分隔线分开。
    ///
    /// 外观筛选控件放在头部行右侧（而不是左侧列表栏顶部）：头部行因此和其它
    /// 分栏页一样有控件撑着，分隔线落在同一水平线上。
    private var regularBody: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    headerStats
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                    AppDivider()
                    HStack(spacing: 0) {
                        themeListPane.frame(width: 300)
                        AppDivider(.vertical)
                        themeDetailPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)
                }
                // 共享 scaffold 给内容留了左右 24，这里把整列加宽 48 并左移 24，
                // 使主从容器正好贴到窗口左右边缘；标题行再自行补回 24 留白。
                .frame(width: proxy.size.width + 48, alignment: .topLeading)
                .offset(x: -24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label(String(format: LumiThemePackLocalization.string("%lld Themes"), Int64(theme.themes.count)), systemImage: "paintpalette")
            if let activeID = theme.selectedThemeId,
               let active = theme.themes.first(where: { $0.id == activeID }) {
                Text(String(format: LumiThemePackLocalization.string("Current: %@"), active.displayName))
            }
            Spacer()
            themeFilterControls
        }
        .font(.appCaption)
        .foregroundStyle(uiTheme.textSecondary)
    }

    private var themeListPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredThemes) { item in themeListRow(item) }
                    if filteredThemes.isEmpty {
                        AppEmptyState(icon: "paintpalette", title: LumiThemePackLocalization.string("No Themes Found"))
                            .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    /// 外观筛选：放在头部行右侧，宽度固定 220。
    ///
    /// `AppSegmentedControl` 自然高度约 25.3，比其它分栏页头部里的
    /// `AppButton(size: .small)`（约 26.8）略矮。这里给一个 27 的下限让它
    /// 与按钮齐平——高度足够时不会触发裁剪，只是把头部行撑到与其它页一致，
    /// 顶部分隔线落在同一水平线上。
    private var themeFilterControls: some View {
        AppSegmentedControl(
            ThemeAppearanceFilter.allCases.map(\.title),
            selection: Binding(
                get: { ThemeAppearanceFilter.allCases.firstIndex(of: appearanceFilter) ?? 0 },
                set: { appearanceFilter = ThemeAppearanceFilter.allCases[$0] }
            ),
            maxWidth: .infinity
        )
        .frame(width: 220, height: 27)
    }

    private func themeListRow(_ item: AppThemeValue) -> some View {
        let isSelected = selectedTheme?.id == item.id
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedID = item.id }
        }) {
            themeListRowContent(item)
        }
    }

    private func themeListRowContent(_ item: AppThemeValue) -> some View {
        let isActive = theme.selectedThemeId == item.id
        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 6) {
                Image(systemName: item.iconName)
                    .font(.appBody)
                    .foregroundStyle(item.resolvedIconColor)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(isActive ? uiTheme.success : uiTheme.textTertiary.opacity(0.45))
                    .frame(width: 6, height: 6)
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(uiTheme.textPrimary)
                    .lineLimit(1)
                Text(item.description)
                    .font(.appMicro)
                    .foregroundStyle(uiTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var themeDetailPane: some View {
        if let selectedTheme {
            ThemePreviewPane(
                item: selectedTheme,
                isActive: theme.selectedThemeId == selectedTheme.id,
                containerBackground: uiTheme.surface,
                onApply: { try? theme.selectTheme(id: selectedTheme.id) }
            )
        } else {
            AppEmptyState(icon: "paintpalette", title: LumiThemePackLocalization.string("Select a Theme"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

}

@MainActor
private final class ThemeSettingsObservationModel: ObservableObject {
    @Published private(set) var revision = 0
    private var handle: (any ThemeProvidingObserverHandle)?

    init(theme: any ThemeProviding) {
        handle = theme.addObserver { [weak self] _ in
            self?.revision += 1
        }
    }

}

private struct ThemePreviewPane: View {
    let item: AppThemeValue
    let isActive: Bool
    /// 预览容器沿用当前生效主题，浏览待应用主题时不改变设置页背景。
    let containerBackground: Color
    let onApply: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var palette: LumiThemePalette { item.palette }
    private var primary: Color { palette.accentPrimary.color() }
    private var secondary: Color { palette.accentSecondary.color() }
    private var background: Color { palette.backgroundMedium.color() }
    private var elevated: Color { palette.backgroundLight.color() }
    private var textPrimary: Color { palette.textPrimary.color() }
    private var textSecondary: Color { palette.textSecondary.color() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 12)
            AppDivider()
            ScrollView {
                preview
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(containerBackground)
        .accessibilityIdentifier("wakey.theme.preview-pane")
    }

    @ViewBuilder
    private var header: some View {
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    previewIcon
                    headerText
                }
                headerAction
            }
        } else {
            HStack(alignment: .top, spacing: 16) {
                previewIcon
                headerText
                headerAction
            }
        }
    }

    private var previewIcon: some View {
        Image(systemName: item.iconName)
            .font(.system(size: 38, weight: .semibold))
            .foregroundStyle(item.resolvedIconColor)
            .frame(width: 64, height: 64)
            .background(primary.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.displayName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(textPrimary)
            Text(item.description)
                .font(.appCaption)
                .foregroundStyle(textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(appearanceLabel)
                .font(.appMicro)
                .foregroundStyle(textSecondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var headerAction: some View {
        if isActive {
            AppTag(LumiThemePackLocalization.string("Currently Using"), style: .accent)
        } else {
            AppButton(LumiThemePackLocalization.string("Use"), systemImage: "paintbrush.fill", style: .primary, size: .small, action: onApply)
        }
    }

    private var appearanceLabel: String {
        switch item.appearanceKind {
        case .dark: LumiThemePackLocalization.string("Dark Theme")
        case .light: LumiThemePackLocalization.string("Light Theme")
        case .system: LumiThemePackLocalization.string("Follow System Appearance")
        }
    }

    @ViewBuilder
    private var preview: some View {
        if horizontalSizeClass == .compact {
            VStack(spacing: 14) {
                typographyCard
                colorsCard
                controlsCard
                listStatusCard
            }
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible())],
                spacing: 14
            ) {
                typographyCard.frame(height: 200)
                colorsCard.frame(height: 200)
                controlsCard.frame(height: 200)
                listStatusCard.frame(height: 200)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(elevated.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var typographyCard: some View {
        previewCard(title: LumiThemePackLocalization.string("Typography & Actions"), systemImage: "textformat") {
            VStack(alignment: .leading, spacing: 8) {
                Text(LumiThemePackLocalization.string("Primary Text"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(textPrimary)
                Text(LumiThemePackLocalization.string("Secondary Text"))
                    .font(.appBody)
                    .foregroundStyle(textSecondary)
                Text(LumiThemePackLocalization.string("Theme Color & Elevation Preview"))
                    .font(.appMicro)
                    .foregroundStyle(textSecondary.opacity(0.75))
                HStack(spacing: 8) {
                    previewButton(LumiThemePackLocalization.string("Primary Action"), fill: primary, foreground: .white)
                    previewButton(LumiThemePackLocalization.string("Secondary Action"), fill: elevated, foreground: textPrimary)
                    previewButton(LumiThemePackLocalization.string("Tertiary Action"), fill: secondary.opacity(0.18), foreground: secondary)
                }
            }
        }
    }

    private var colorsCard: some View {
        previewCard(title: LumiThemePackLocalization.string("Accent"), systemImage: "paintpalette") {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                colorSwatch(LumiThemePackLocalization.string("Primary Color"), primary)
                colorSwatch(LumiThemePackLocalization.string("Secondary Color"), secondary)
                colorSwatch(LumiThemePackLocalization.string("Background"), background)
                colorSwatch(LumiThemePackLocalization.string("Elevated"), elevated)
            }
            HStack(spacing: 8) {
                Text(LumiThemePackLocalization.string("Surface Depth"))
                    .font(.appMicro)
                    .foregroundStyle(textSecondary)
                ProgressView(value: 0.68)
                    .tint(primary)
                Text(verbatim: "68%")
                    .font(.appMicroEmphasized)
                    .foregroundStyle(textPrimary)
            }
        }
    }

    private var controlsCard: some View {
        previewCard(title: LumiThemePackLocalization.string("Controls"), systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(LumiThemePackLocalization.string("System Sync"), isOn: .constant(true))
                    .font(.appCaption)
                    .foregroundStyle(textPrimary)
                    .tint(primary)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(LumiThemePackLocalization.string("Display Density"))
                        Spacer()
                        Text(LumiThemePackLocalization.string("Comfortable"))
                    }
                    .font(.appMicro)
                    .foregroundStyle(textSecondary)
                    Slider(value: .constant(0.68))
                        .tint(primary)
                }

                Picker(LumiThemePackLocalization.string("Appearance"), selection: .constant(1)) {
                    Text(LumiThemePackLocalization.string("Compact")).tag(0)
                    Text(LumiThemePackLocalization.string("Comfortable")).tag(1)
                    Text(LumiThemePackLocalization.string("Spacious")).tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .tint(primary)
            }
        }
    }

    private var listStatusCard: some View {
        previewCard(title: LumiThemePackLocalization.string("Lists & Status"), systemImage: "list.bullet.rectangle") {
            VStack(spacing: 8) {
                previewListRow(
                    title: "main",
                    detail: LumiThemePackLocalization.string("Workspace"),
                    systemImage: "arrow.triangle.branch",
                    isSelected: true
                )
                previewListRow(
                    title: "feature/preview",
                    detail: LumiThemePackLocalization.string("3 Changes"),
                    systemImage: "arrow.triangle.branch",
                    isSelected: false
                )
                HStack(spacing: 8) {
                    previewBadge(LumiThemePackLocalization.string("Ready"), color: primary)
                    previewBadge(LumiThemePackLocalization.string("3 Changes"), color: secondary)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func previewCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(primary)
                Text(title)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(textPrimary)
            }
            content()
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(background.opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(textSecondary.opacity(0.14), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func previewListRow(title: String, detail: String, systemImage: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.appMicroEmphasized)
                .foregroundStyle(isSelected ? primary : textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appMicroEmphasized)
                    .foregroundStyle(textPrimary)
                Text(detail)
                    .font(.appMicro)
                    .foregroundStyle(textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.appMicro)
                .foregroundStyle(isSelected ? primary : textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? primary.opacity(0.12) : elevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func previewBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.appMicroEmphasized)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private func previewButton(_ title: String, fill: Color, foreground: Color) -> some View {
        Text(title)
            .font(.appMicroEmphasized)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func colorSwatch(_ title: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 44, height: 28)
            Text(title)
                .font(.appMicro)
                .foregroundStyle(textSecondary)
        }
    }
}

#if os(iOS)
/// iOS 主题预览弹层。
///
/// 桌面端的主题预览是一整块「控件拼贴」面板，直接搬到 iPhone 上既拥挤又不像设置界面。
/// 这里收敛为一页可滚动的原生分组：主题标识、配色样本、控件样例。
private struct IOSThemePreviewSheet: View {
    let theme: AppThemeValue

    @Environment(\.dismiss) private var dismiss

    private var palette: LumiThemePalette { theme.palette }

    private var primary: Color { palette.accentPrimary.color() }
    private var secondary: Color { palette.accentSecondary.color() }
    private var background: Color { palette.backgroundMedium.color() }
    private var elevated: Color { palette.backgroundLight.color() }
    private var textPrimary: Color { palette.textPrimary.color() }
    private var textSecondary: Color { palette.textSecondary.color() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    AppSettingSection(title: LumiThemePackLocalization.string("Accent")) {
                        swatchRow
                    }
                    AppSettingSection(title: LumiThemePackLocalization.string("Controls")) {
                        controlSamples
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color.lumiGroupedBackground)
            .navigationTitle(theme.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LumiThemePackLocalization.string("Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: theme.iconName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(theme.resolvedIconColor)
                .frame(width: 56, height: 56)
                .background(primary.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(theme.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(textPrimary)
                Text(theme.description)
                    .font(.footnote)
                    .foregroundStyle(textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var swatchRow: some View {
        HStack(spacing: 10) {
            swatch(primary)
            swatch(secondary)
            swatch(background)
            swatch(elevated)
            swatch(textPrimary)
        }
        .padding(.vertical, 4)
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(height: 40)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    private var controlSamples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LumiThemePackLocalization.string("Primary Text"))
                .font(.body)
                .foregroundStyle(textPrimary)

            Text(LumiThemePackLocalization.string("Secondary Text"))
                .font(.footnote)
                .foregroundStyle(textSecondary)

            HStack(spacing: 10) {
                Text(LumiThemePackLocalization.string("Primary Action"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(primary)
                    .clipShape(Capsule())

                Text(LumiThemePackLocalization.string("Secondary Action"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(elevated)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
