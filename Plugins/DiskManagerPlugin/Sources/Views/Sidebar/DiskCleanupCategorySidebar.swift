import SwiftUI
import LumiUI
import LumiKernel

/// 磁盘清理类型侧边栏（RailView 架构）。
///
/// 由 ``DiskManagerPlugin`` 注册为 `PanelRailTabItem`，仅在 DiskManager
/// ViewContainer 中可见。该视图取代了原 ``DiskManagerView`` 顶部的
/// `ViewModeSelector`，与主视图通过 ``DiskCleanupCategoryStore`` 共享状态。
///
/// 布局（自上而下）：
/// 1. 顶部 `ViewModeHeaderBar`（标题 + 图标）；
/// 2. 磁盘使用情况卡 ``DiskUsageInfoView``；
/// 3. 分隔线；
/// 4. `LazyVStack` 列表（清理类型），每行用 `AppListRow`，选中时显示 checkmark。
///
/// 样式与 `ConversationListPlugin` / `DatabaseManagerPlugin` 的 Rail 列表保持一致。
struct DiskCleanupCategorySidebar: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var store: DiskCleanupCategoryStore

    var body: some View {
        VStack(spacing: 0) {
            header

            DiskUsageInfoView()
                .padding(.horizontal, 10)
                .padding(.top, 8)

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(DiskCleanupCategory.allCases) { category in
                        AppListRow(
                            isSelected: store.selected == category,
                            action: { store.select(category) }
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: category.systemImage)
                                    .foregroundStyle(.secondary)
                                Text(category.title)
                                    .font(.appMicroEmphasized)
                                    .foregroundColor(theme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: 0)
                                if store.selected == category {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "internaldrive")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("Disk Cleanup", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06))
    }
}

#if DEBUG
#Preview("Cleanup Categories") {
    DiskCleanupCategorySidebar(store: DiskCleanupCategoryStore())
        .frame(width: 240, height: 520)
}
#endif
