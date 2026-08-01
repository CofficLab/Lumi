import AppKit
import LumiKernel
import LumiUI
import SwiftUI

/// Layout 设置视图。
///
/// - 顶部全局区：容器总数 + 当前激活容器，右上角按钮可打开数据目录。
/// - 左侧列出所有 ViewContainer，点击在右侧展示其完整布局状态（只读）。
///
/// 所有数据均只读展示当前内存中的运行时状态（与磁盘持久化内容一致），
/// 不在此页面做任何写入。
@MainActor
public struct LayoutSettingsView: View {
    @ObservedObject private var kernel: LumiKernel
    @LumiTheme private var theme

    @State private var selectedContainerID: String?
    @State private var didSeedSelection = false

    public init(kernel: LumiKernel) {
        self._kernel = ObservedObject(wrappedValue: kernel)
    }

    private var containers: [ViewContainerItem] {
        kernel.workspace?.allViewContainers ?? []
    }

    private var containerIDs: [String] {
        containers.map(\.id)
    }

    private var activeContainerID: String? {
        kernel.workspace?.activeViewContainerID
    }

    private var selectedContainer: ViewContainerItem? {
        guard let selectedContainerID else { return nil }
        return containers.first { $0.id == selectedContainerID }
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                header

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 560, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { seedSelectionIfNeeded() }
        .onChange(of: containerIDs) { _, _ in syncSelectionAfterContainerChange() }
    }

    // MARK: - Header（全局区）

    private var header: some View {
        HStack(spacing: 10) {
            Label("\(containers.count) containers", systemImage: "sidebar.leading")
            if let active = activeContainerName {
                Text("·")
                Text(active)
            }
            Spacer()
            AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var activeContainerName: String? {
        guard let activeContainerID else { return nil }
        return containers.first { $0.id == activeContainerID }?.title
    }

    // MARK: - Sidebar（容器列表）

    private var sidebar: some View {
        VStack(spacing: 0) {
            if containers.isEmpty {
                AppEmptyState(
                    icon: "sidebar.leading",
                    title: "No containers registered"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(containers) { container in
                            containerRow(container)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func containerRow(_ container: ViewContainerItem) -> some View {
        let isSelected = selectedContainerID == container.id
        let isCurrent = activeContainerID == container.id
        return AppListRow(isSelected: isSelected, action: {
            selectedContainerID = container.id
            didSeedSelection = true
        }) {
            HStack(spacing: 10) {
                Image(systemName: container.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(container.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        if isCurrent {
                            Text("Current")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                    Text(container.id)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Detail Pane（容器详情，只读）

    @ViewBuilder
    private var detailPane: some View {
        if let container = selectedContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    overviewSection(container)
                    basicInfoSection(container)
                    visibilityDeclaredSection(container)
                    visibilityOverrideSection(container)
                    tabsSection(container)
                    dividersSection(container)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "sidebar.leading",
                title: containers.isEmpty ? "No containers registered" : "Select a container"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    @ViewBuilder
    private func overviewSection(_ container: ViewContainerItem) -> some View {
        AppSettingsSection(title: "Overview") {
            VStack(alignment: .leading, spacing: 10) {
                Text(container.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Text(container.id)
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func basicInfoSection(_ container: ViewContainerItem) -> some View {
        let isCurrent = activeContainerID == container.id
        return AppSettingsSection(title: "Basic Info") {
            VStack(spacing: 0) {
                detailRow(title: "Order", icon: "arrow.up.arrow.down", value: "\(container.order)")
                Divider().padding(.vertical, 8)
                detailRow(title: "Has View", icon: "rectangle.dashed", value: container.makeView != nil ? "Yes" : "No")
                Divider().padding(.vertical, 8)
                detailRow(title: "Status", icon: "star", value: isCurrent ? "Active Container" : "Inactive")
            }
        }
    }

    /// 容器注册时静态声明的可见性（ViewContainerItem 上的 Bool?）。
    private func visibilityDeclaredSection(_ container: ViewContainerItem) -> some View {
        AppSettingsSection(title: "Visibility (Declared)", subtitle: "容器注册时声明的默认可见性") {
            VStack(spacing: 0) {
                detailRow(title: "Rail", icon: "sidebar.left", value: boolText(container.isRailVisible))
                Divider().padding(.vertical, 8)
                detailRow(title: "Chat", icon: "rectangle.rightthird.inset.filled", value: boolText(container.isChatVisible))
                Divider().padding(.vertical, 8)
                detailRow(title: "Content", icon: "rectangle.split.3x1", value: boolText(container.isContentVisible))
                Divider().padding(.vertical, 8)
                detailRow(title: "Panel", icon: "rectangle.inset.filled", value: boolText(container.isPanelVisible))
                Divider().padding(.vertical, 8)
                detailRow(title: "Panel Header", icon: "rectangle.topthird.inset.filled", value: boolText(container.isPanelHeaderVisible))
                Divider().padding(.vertical, 8)
                detailRow(title: "Panel Bottom", icon: "rectangle.bottomthird.inset.filled", value: boolText(container.isPanelBottomVisible))
            }
        }
    }

    /// 用户手动调整过、已持久化的可见性覆盖（visibilityOverrides）。
    private func visibilityOverrideSection(_ container: ViewContainerItem) -> some View {
        let overrides = kernel.workspace?.visibilityOverride(for: container.id)
        return AppSettingsSection(title: "Visibility (User Override)", subtitle: "用户手动调整后记忆的值，优先级最高") {
            if let overrides {
                VStack(spacing: 0) {
                    detailRow(title: "Rail", icon: "sidebar.left", value: boolText(overrides.isRailVisible))
                    Divider().padding(.vertical, 8)
                    detailRow(title: "Chat", icon: "rectangle.rightthird.inset.filled", value: boolText(overrides.isChatVisible))
                    Divider().padding(.vertical, 8)
                    detailRow(title: "Content", icon: "rectangle.split.3x1", value: boolText(overrides.isContentVisible))
                    Divider().padding(.vertical, 8)
                    detailRow(title: "Panel", icon: "rectangle.inset.filled", value: boolText(overrides.isPanelVisible))
                    Divider().padding(.vertical, 8)
                    detailRow(title: "Panel Header", icon: "rectangle.topthird.inset.filled", value: boolText(overrides.isPanelHeaderVisible))
                    Divider().padding(.vertical, 8)
                    detailRow(title: "Panel Bottom", icon: "rectangle.bottomthird.inset.filled", value: boolText(overrides.isPanelBottomVisible))
                }
            } else {
                Text("No user override — falls back to declared values")
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func tabsSection(_ container: ViewContainerItem) -> some View {
        let state = kernel.workspace
        return AppSettingsSection(title: "Tabs", subtitle: "该容器上次选中的侧边栏 / 底部标签") {
            VStack(spacing: 0) {
                detailRow(title: "Rail Tab", icon: "sidebar.left", value: state?.activeRailTabID(for: container.id) ?? "—", monospace: true)
                Divider().padding(.vertical, 8)
                detailRow(title: "Bottom Tab", icon: "rectangle.split.2x1", value: state?.activeBottomTabID(for: container.id) ?? "—", monospace: true)
            }
        }
    }

    private func dividersSection(_ container: ViewContainerItem) -> some View {
        let state = kernel.workspace
        return AppSettingsSection(title: "Dividers", subtitle: "该容器的分栏位置（pt）") {
            VStack(spacing: 0) {
                detailRow(title: "Rail Width", icon: "sidebar.left", value: dividerText(state?.storedRailDivider(for: container.id)))
                Divider().padding(.vertical, 8)
                detailRow(title: "Chat (Narrow)", icon: "rectangle.rightthird.inset.filled", value: dividerText(state?.storedChatSectionDivider(for: container.id, layout: .narrow)))
                Divider().padding(.vertical, 8)
                detailRow(title: "Chat (Wide)", icon: "rectangle.rightthird.inset.filled", value: dividerText(state?.storedChatSectionDivider(for: container.id, layout: .wide)))
                Divider().padding(.vertical, 8)
                detailRow(title: "Bottom Panel Height", icon: "rectangle.split.2x1", value: dividerText(state?.storedBottomPanelDivider(for: container.id)))
            }
        }
    }

    // MARK: - Helpers

    private func detailRow(title: String, icon: String, value: String, monospace: Bool = false) -> some View {
        AppSettingRow(title: title, icon: icon) {
            Text(value)
                .font(monospace ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    /// Bool? → "true" / "false" / "—"（nil 表示未声明）。
    private func boolText(_ value: Bool?) -> String {
        guard let value else { return "—" }
        return value ? "true" : "false"
    }

    /// CGFloat? → 整数 pt 字符串；nil → "default"。
    private func dividerText(_ value: CGFloat?) -> String {
        guard let value else { return "default" }
        return String(format: "%.0f pt", value)
    }

    // MARK: - Selection Sync

    private func seedSelectionIfNeeded() {
        guard !didSeedSelection else { return }
        didSeedSelection = true
        selectedContainerID = activeContainerID ?? containers.first?.id
    }

    private func syncSelectionAfterContainerChange() {
        if !didSeedSelection {
            seedSelectionIfNeeded()
            return
        }
        guard let selectedContainerID, containers.contains(where: { $0.id == selectedContainerID }) else {
            self.selectedContainerID = containers.first?.id
            return
        }
    }

    // MARK: - Actions

    private func openDataDirectory() {
        guard let url = kernel.workspace?.settingsDirectory else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
