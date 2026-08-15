import LumiUI
import KernelLumi
import SwiftUI

struct ControlView: View {
    @LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference
    @ObservedObject private var viewModel: ProjectsViewModel
    @ObservedObject private var kernel: KernelLumi
    @State private var isPopoverPresented = false
    @State private var isHovering = false
    @State private var activeContainerRevision = 0
    @State private var conversationsRevision = 0

    init(viewModel: ProjectsViewModel, kernel: KernelLumi) {
        self.viewModel = viewModel
        self.kernel = kernel
    }

    /// 新用户（会话与项目均为零）时隐藏工具栏控件：
    /// 此时空态已有「添加项目」动作胶囊作为唯一项目入口，标题栏再显示
    /// 一个 Projects 下拉会分散视觉焦点。一旦产生首个会话或首个项目即恢复。
    private var isNewUser: Bool {
        (kernel.conversations?.conversations.isEmpty ?? true)
            && viewModel.projects.isEmpty
    }

    var body: some View {
        let _ = activeContainerRevision
        let _ = conversationsRevision
        let supportsProject = kernel.workspace?.currentViewContainer?.supportsProject == true

        Group {
            if supportsProject && !isNewUser {
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
                    PopoverView(viewModel: viewModel)
                }
                .onHover { hovering in
                    LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                        isHovering = hovering
                    }
                }
                .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHighlighted)
            }
        }
        .onAppear {
            activeContainerRevision += 1
        }
        .onActiveViewContainerIDDidChange { _ in
            activeContainerRevision += 1
            if !supportsProject {
                isPopoverPresented = false
            }
        }
        .onLumiConversationsDidChange {
            // 会话列表变化时刷新「新用户」判定（如新建首个会话后恢复工具栏）。
            conversationsRevision += 1
        }
    }

    /// 控件是否应显示高亮（悬停或弹层已展开）。
    private var isHighlighted: Bool {
        isHovering || isPopoverPresented
    }
}
