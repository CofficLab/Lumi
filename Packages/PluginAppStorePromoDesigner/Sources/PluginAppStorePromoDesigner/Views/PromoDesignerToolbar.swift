import KitAppStorePromo
import LumiUI
import SwiftUI

/// 设计师面板顶部工具栏：语言、Display 选择与刷新。
struct PromoDesignerTopToolbar: View {
    @ObservedObject var workspace: WorkspaceStore
    let task: AppStorePromoTask
    let onRefresh: () -> Void

    // MARK: - 初始化

    init(
        workspace: WorkspaceStore,
        task: AppStorePromoTask,
        onRefresh: @escaping () -> Void
    ) {
        self.workspace = workspace
        self.task = task
        self.onRefresh = onRefresh
    }

    // MARK: - Body

    var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .toolbar,
            padding: EdgeInsets(
                top: DesignTokens.Spacing.sm,
                leading: DesignTokens.Spacing.md,
                bottom: DesignTokens.Spacing.sm,
                trailing: DesignTokens.Spacing.md
            )
        ) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                languagePicker
                displayPicker
                Spacer(minLength: 0)

                AppIconButton(
                    systemImage: "arrow.clockwise",
                    action: onRefresh
                )
                .accessibilityLabel(PromoLocalization.string("Refresh"))
                .help(PromoLocalization.string("Refresh"))
            }
        }
        .borderBottom()
    }

    // MARK: - 子视图

    @ViewBuilder
    private var languagePicker: some View {
        if let image = workspace.selectedImage {
            Menu {
                ForEach(image.image.localeIdentifiers, id: \.self) { localeIdentifier in
                    Button {
                        workspace.selectLocale(localeIdentifier)
                    } label: {
                        let locale = AppStorePromoLocale(identifier: localeIdentifier)
                        if localeIdentifier == workspace.selectedLocaleIdentifier {
                            Label(locale.displayName, systemImage: "checkmark")
                        } else {
                            Text(locale.displayName)
                        }
                    }
                }

                Divider()

                Menu {
                    let existing = Set(image.image.localeIdentifiers)
                    ForEach(AppStorePromoLocale.common.filter { !existing.contains($0.identifier) }) { locale in
                        Button(locale.displayName) {
                            workspace.addLocale(locale.identifier)
                        }
                    }
                } label: {
                    Label(PromoLocalization.string("Add Language"), systemImage: "plus")
                }
            } label: {
                Label(
                    AppStorePromoLocale(identifier: image.localeIdentifier).localizedName,
                    systemImage: "globe"
                )
            }
            .help(PromoLocalization.string("Preview Language"))
            .accessibilityLabel(PromoLocalization.string("Preview Language"))
        }
    }

    @ViewBuilder
    private var displayPicker: some View {
        Picker(PromoLocalization.string("Display"), selection: $workspace.selectedDisplayType) {
            ForEach(AppStorePromoDisplaySpec.presets(for: task.deviceFamily)) { preset in
                Text("\(preset.displayType) · \(preset.width)×\(preset.height)").tag(preset.displayType)
            }
        }
        .labelsHidden()
        .frame(maxWidth: 260)
    }

}

/// 设计师面板底部工具栏：预览 / HTML 源码切换与导出。
struct PromoDesignerBottomToolbar: View {
    let mode: Binding<PromoDesignerView.Mode>
    let isExporting: Bool
    let onExport: () -> Void

    var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .toolbar,
            padding: EdgeInsets(
                top: DesignTokens.Spacing.sm,
                leading: DesignTokens.Spacing.md,
                bottom: DesignTokens.Spacing.sm,
                trailing: DesignTokens.Spacing.md
            )
        ) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                modePicker
                Spacer(minLength: 0)
                AppButton(
                    PromoLocalization.string("Export"),
                    systemImage: "square.and.arrow.down",
                    style: .primary,
                    size: .small,
                    action: onExport
                )
                .disabled(isExporting)
                if isExporting {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .borderTop()
    }

    private var modePicker: some View {
        AppSegmentedControl(
            [
                PromoLocalization.string("Preview"),
                PromoLocalization.string("HTML Source")
            ],
            selection: modeIndex,
            maxWidth: 190
        )
        .accessibilityLabel(PromoLocalization.string("Mode"))
    }

    private var modeIndex: Binding<Int> {
        Binding(
            get: { mode.wrappedValue == .preview ? 0 : 1 },
            set: { mode.wrappedValue = $0 == 0 ? .preview : .source }
        )
    }
}

// MARK: - 预览

#Preview {
    PromoDesignerTopToolbar(
        workspace: WorkspaceStore.shared,
        task: AppStorePromoTask(
            id: "preview",
            title: PromoLocalization.string("Launch Campaign"),
            appName: "Demo",
            deviceFamily: .iphone,
            images: []
        ),
        onRefresh: {}
    )
    .padding()
    .frame(width: 800)
}
