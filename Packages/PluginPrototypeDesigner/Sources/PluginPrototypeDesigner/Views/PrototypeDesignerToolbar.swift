import KitPrototype
import LumiUI
import SwiftUI

/// 原型设计器顶部工具栏：展示设备与风格信息，并提供刷新。
struct PrototypeDesignerTopToolbar: View {
    @ObservedObject var workspace: WorkspaceStore
    let screen: PrototypeScreen
    let onRefresh: () -> Void

    // MARK: - 初始化

    init(
        workspace: WorkspaceStore,
        screen: PrototypeScreen,
        onRefresh: @escaping () -> Void
    ) {
        self.workspace = workspace
        self.screen = screen
        self.onRefresh = onRefresh
    }

    // MARK: - Body

    var body: some View {
        AppToolbarContainer {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let project = workspace.selectedProject {
                    AppToolbarTitleLabel(
                        icon: project.style == .wireframe ? "rectangle.dashed" : "paintbrush.pointed",
                        title: screen.title
                    )
                    AppTag(project.style.rawValue, style: .subtle)
                    AppTag(deviceLabel(project.device), systemImage: "iphone", style: .subtle)
                }
                Spacer(minLength: 0)

                if !screen.hotspots.isEmpty {
                    AppTag(
                        "\(screen.hotspots.count) \(PrototypeLocalization.string("links"))",
                        systemImage: "arrow.turn.down.right",
                        style: .subtle
                    )
                }

                AppIconButton(systemImage: "arrow.clockwise", action: onRefresh)
                    .accessibilityLabel(PrototypeLocalization.string("Refresh"))
                    .help(PrototypeLocalization.string("Refresh"))
            }
        }
        .borderBottom()
    }

    // MARK: - 私有方法

    private func deviceLabel(_ device: PrototypeDevice) -> String {
        "\(device.kind.displayName) · \(Int(device.width))×\(Int(device.height))@\(Int(device.scale))x"
    }
}

/// 原型设计器底部工具栏：预览 / HTML 源码切换与导出。
struct PrototypeDesignerBottomToolbar: View {
    let mode: Binding<PrototypeDesignerView.Mode>
    let isExporting: Bool
    let onExport: () -> Void

    var body: some View {
        AppToolbarContainer {
            HStack(spacing: DesignTokens.Spacing.sm) {
                modePicker
                Spacer(minLength: 0)
                AppButton(
                    PrototypeLocalization.string("Export"),
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
                PrototypeLocalization.string("Preview"),
                PrototypeLocalization.string("HTML Source")
            ],
            selection: modeIndex,
            maxWidth: 190
        )
        .accessibilityLabel(PrototypeLocalization.string("Mode"))
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
    let project = PrototypeProject(
        id: "preview",
        title: "Checkout Flow",
        style: .wireframe,
        device: PrototypeDeviceKind.iPhone15Pro.preset!,
        screens: [
            PrototypeScreen(
                id: "01-home",
                title: "首页",
                order: 0,
                hotspots: [PrototypeHotspot(targetScreenID: "02-detail", label: "进入详情")]
            )
        ]
    )
    VStack(spacing: 0) {
        PrototypeDesignerTopToolbar(
            workspace: WorkspaceStore.shared,
            screen: project.screens[0],
            onRefresh: {}
        )
        PrototypeDesignerBottomToolbar(
            mode: .constant(.preview),
            isExporting: false,
            onExport: {}
        )
    }
    .frame(width: 800)
}
