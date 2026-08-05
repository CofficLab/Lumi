import LumiKernel
import LumiUI
import SwiftUI

/// 标题工具栏右上角的「数据库」入口按钮。
///
/// 参考 `WorkspacePlugin/LayoutMenuButton` 的写法，使用 `AppIconButton` 渲染，
/// 点击后弹出 ``DatabaseConnectionPopoverView`` 提供连接管理。
///
/// 仅在对应的 view container 激活时显示，避免在其它面板上出现孤儿按钮。
///
/// 判定策略：
/// - 主体在 `body` 内实时计算 `kernel.workspace?.activeViewContainerID == containerID`，
///   不依赖 `onAppear` 的延迟执行；首次启动时直接读取已从磁盘恢复的值，
///   避免 `Group { if isVisible }` + 默认值 false 导致的「首次构建不可见」死锁。
/// - 同时订阅 `.onActiveViewContainerIDDidChange`，把最新值缓存到 `@State`，
///   保证 SwiftUI 因其它原因未重算 body 时仍能触发刷新（切到其它容器再切回仍可见）。
public struct DatabaseToolbarButton: View {
    @LumiTheme private var theme
    @ObservedObject private var kernel: LumiKernel

    /// 仅当 `kernel.workspace.activeViewContainerID == containerID` 时显示按钮。
    let containerID: String

    /// 由 ``DatabaseManagerPlugin`` 注入，与 ``DatabaseMainView`` 共享同一个实例，
    /// 保证在工具栏 popover 中选中/断开连接立即反映到主面板。
    @ObservedObject var viewModel: DatabaseViewModel

    /// 缓存最近一次通知得到的 container id；在 body 因任何原因没及时重算时，
    /// 用作显隐判断的回退值。
    @State private var cachedActiveID: String?

    @State private var isPopoverPresented: Bool = false

    public init(kernel: LumiKernel, containerID: String, viewModel: DatabaseViewModel) {
        self._kernel = ObservedObject(wrappedValue: kernel)
        self.containerID = containerID
        self.viewModel = viewModel
        // 不在 init 中读 layoutManager（@State 初始化时序不可靠，留给 body 实时计算）。
    }

    public var body: some View {
        let liveID = kernel.workspace?.activeViewContainerID
        // 用缓存值兜底，确保即使 body 因任何原因没重算，
        // 也能反映上一次通知得到的激活容器 id。
        let resolvedID = liveID ?? cachedActiveID
        let isVisible = resolvedID == containerID

        Group {
            if isVisible {
                AppIconButton(
                    systemImage: "cylinder.split.1x2",
                    isActive: isPopoverPresented
                ) {
                    isPopoverPresented.toggle()
                }
                .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                    ConnectionPopoverView(
                        viewModel: viewModel,
                        isPopoverPresented: $isPopoverPresented
                    )
                    .appSurface(style: .popover, cornerRadius: 8, borderColor: theme.divider)
                    .appThemedAppearance()
                    .background {
                        ThemeWindowAppearanceBridge()
                    }
                }
                .help(LumiPluginLocalization.string("Database Connections", bundle: .module))
            }
        }
        .onActiveViewContainerIDDidChange { activeID in
            cachedActiveID = activeID
        }
    }
}
