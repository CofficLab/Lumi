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
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .semibold))

                Text(viewModel.currentProject?.name ?? LumiPluginLocalization.string("Projects", bundle: .module))
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

    private func presentImporter() {
        isPopoverPresented = false

        // Let the popover finish dismissing before the file importer asks the
        // main window to present its panel.
        Task { @MainActor in
            await Task.yield()
            isImporterPresented = true
        }
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        guard case let .success(urls) = result,
              let url = urls.first else {
            return
        }

        viewModel.addProject(url: url)
    }
}
