import LumiUI
import SwiftUI
import UniformTypeIdentifiers

/// 标题栏项目控件：显示当前项目名称，点击弹出项目列表。
struct ControlView: View {
    @LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference
    @ObservedObject private var viewModel: ProjectsViewModel
    @State private var isPopoverPresented = false
    @State private var isImporterPresented = false
    @State private var isHovering = false

    init(viewModel: ProjectsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        // 显式读取存储状态修订号：缓存失效后需要重新探测存储类型，
        // 依赖它才能让胶囊图标随之刷新。
        let _ = viewModel.storageRevision

        return Button {
            isPopoverPresented = true
            refreshStorageKinds()
        } label: {
            HStack(spacing: 6) {
                // 外置设备（U 盘、移动硬盘）用硬盘图标，与本机磁盘区分。
                ProjectStorageIcon(kind: storageKind)
                    .help(storageHint)

                Text(viewModel.currentProject?.name ?? pluginLocalization.string("Projects"))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                // 下拉箭头：明示这是一个可展开的控件，而非静态标签；
                // 弹层展开时翻转为向上，给出"已展开/可收起"的反馈。
                Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .appSurface(
                style: isHighlighted ? .listRowHover : .listRow,
                cornerRadius: 6,
                borderColor: isHighlighted ? theme.appHoverBorder : nil
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            PopoverView(viewModel: viewModel, requestImporter: presentImporter)
        }
        // Present the importer from the toolbar host rather than from the
        // popover. macOS can leave a SwiftUI fileImporter attached to an
        // NSPopover spinning while it tries to create the file panel.
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovering = hovering
            }
        }
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHighlighted)
    }

    /// 控件是否应显示高亮（悬停或弹层已展开）。
    private var isHighlighted: Bool {
        isHovering || isPopoverPresented
    }

    /// 当前项目的存储类型；无项目时按本机磁盘处理。
    private var storageKind: ProjectStorageKind {
        guard let path = viewModel.currentProject?.path else { return .internalDisk }
        return ProjectStorageDetector.kind(for: path)
    }

    /// 当前项目的存储状态提示；无项目或状态正常时为空串。
    private var storageHint: String {
        ProjectStorageHint.text(for: storageKind)
    }

    private func presentImporter() {
        isPopoverPresented = false

        // Let the popover finish dismissing before the file importer asks the
        // main window to present its panel.
        Task { @MainActor in
            await Task.yield()
            isImporterPresented = true
        }
    }

    /// 弹层展开时刷新存储类型缓存。
    ///
    /// 外置设备可能在应用运行期间被拔出或重新挂载，缓存的判定结果会过期；
    /// 用户打开弹层时重新探测一次即可，无需常驻轮询。
    private func refreshStorageKinds() {
        viewModel.refreshStorageState()
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        guard case let .success(urls) = result,
              let url = urls.first else {
            return
        }

        viewModel.addProject(url: url)
    }
}
