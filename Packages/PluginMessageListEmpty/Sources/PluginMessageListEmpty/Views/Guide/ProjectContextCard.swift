import LumiUI
import ProviderConversation
import ProviderProject
import SwiftUI

/// 项目上下文卡：空态里回答「我在哪个项目、它现在是什么状态」。
///
/// ## 它为什么在提示胶囊**下面**
///
/// 标题与胶囊是「提问」这个动作，项目卡是支撑它的上下文。放在标题下面会把
/// 首屏上半部分全变成信息，用户看不到落点；放在下面则形成同宽、同圆角、
/// 同低透明度的上下文列（与活动卡同族）。
///
/// ## 为什么每行都能点
///
/// 一行状态如果既不能点、又不表达任何可执行动作，它就是噪音。因此模型层
/// 只产出**带动作**的行（见 `ProjectContextRow`），点击即跳转。
struct ProjectContextCard: View {
    @LumiTheme private var theme
    let model: ProjectContextViewModel
    let services: MessageListEmptyServices

    var body: some View {
        if let identity = model.identity {
            card(identity)
        }
    }

    private func card(_ identity: ProjectContextIdentity) -> some View {
        VStack(alignment: .leading, spacing: ActivityFusionCardMetrics.anchorSpacing) {
            anchor(identity)

            if !model.rows.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(model.rows) { row in
                        statusRow(row)
                    }
                }
            }

            detail
        }
        .padding(.horizontal, ActivityFusionCardMetrics.horizontalPadding)
        .padding(.vertical, ActivityFusionCardMetrics.verticalPadding)
        .frame(maxWidth: ActivityFusionCardMetrics.maxWidth)
        .background {
            RoundedRectangle(cornerRadius: ActivityFusionCardMetrics.cornerRadius, style: .continuous)
                .fill(theme.primary.opacity(ActivityFusionCardMetrics.fillOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: ActivityFusionCardMetrics.cornerRadius, style: .continuous)
                .stroke(theme.primary.opacity(ActivityFusionCardMetrics.strokeOpacity), lineWidth: 1)
        }
        .shadow(color: theme.primary.opacity(0.05), radius: 10, y: 2)
        // 卡片是这一块区域里**唯一**可寻址的无障碍元素。
        //
        // 标识符会向下传播并覆盖子孙自己的标识符：外层容器一旦带标识符，
        // 卡片与卡内的行就都寻址不到。因此标识符只留在卡片上。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(MessageListEmptyAccessibility.projectContextCardID)
    }

    // MARK: - 组成

    /// 顶部一行锚点：项目名 + 就绪状态。
    private func anchor(_ identity: ProjectContextIdentity) -> some View {
        HStack(spacing: 6) {
            Image(systemName: identity.typeSymbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.primary.opacity(0.9))
                .accessibilityHidden(true)

            Text(identity.name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Text(identity.typeLabels.first ?? pluginLocalization.string("Project"))
                .font(.system(size: 11.5))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 8)
        }
    }

    /// 一行状态。整行都是点击区域。
    private func statusRow(_ row: ProjectContextRow) -> some View {
        Button {
            perform(row.action)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: row.systemImage)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.primary.opacity(0.85))
                    .accessibilityHidden(true)

                Text(row.title)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let detail = row.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 详情：键值对 + 关键文件标签。
    ///
    /// 卡片不再提供折叠开关——项目上下文本来就少，多一次点击才看到信息
    /// 只会把它藏起来。默认展开，内容为空时整段不渲染。
    @ViewBuilder
    private var detail: some View {
        if !model.details.isEmpty || !model.keyFiles.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .overlay(theme.primary.opacity(0.18))

                if !model.details.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(model.details) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(item.label)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(theme.textSecondary)
                                    .frame(width: 92, alignment: .leading)
                                Text(item.value)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                if !model.keyFiles.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(model.keyFiles, id: \.self) { file in
                            Text(file)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(theme.textPrimary.opacity(0.05))
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 动作

    private func perform(_ action: ProjectContextRow.Action) {
        switch action {
        case .openFileTree:
            ProjectContextNavigator.openFileTree(services: services)
        case .openGit:
            ProjectContextNavigator.openGitWorkspace(services: services)
        case let .resumeConversation(id):
            services.conversations?.selectConversation(id: id)
        }
    }
}

/// 跨插件跳转的落点解析。
///
/// ## 为什么按「归属插件」而不是硬编码入口 id
///
/// 入口 id 是各插件的实现细节（`"<plugin id>.entry"`），插件改名就会失效。
/// 按 `ownerPluginID` 找入口、找不到再退回字面量，两级都失效时静默不动作——
/// 跳转失败不该让空态崩溃。
@MainActor
enum ProjectContextNavigator {
    /// 文件树 rail 标签的 id。由 `PluginProjectFileTree` 注册。
    static let fileTreeTabID = "explorer"
    /// Git 工作区插件的 id。
    static let gitWorkspacePluginID = "com.coffic.lumi.plugin.git-workspace"

    /// 打开项目文件树。
    static func openFileTree(services: MessageListEmptyServices) {
        guard let rail = services.railView else { return }
        // 优先按分类找（rail tab 自己声明了业务分类），找不到再退回约定 id。
        if let tab = rail.tabs.first(where: { $0.category == .fileTree }) {
            rail.activateTab(id: tab.id)
        } else {
            rail.activateTabWhenAvailable(id: fileTreeTabID)
        }
    }

    /// 打开 Git 工作区面板。
    static func openGitWorkspace(services: MessageListEmptyServices) {
        guard let activityBar = services.activityBar else { return }
        if let item = activityBar.items.first(where: { $0.ownerPluginID == gitWorkspacePluginID }) {
            activityBar.activateItem(id: item.id)
        } else {
            activityBar.activateItem(id: "\(gitWorkspacePluginID).entry")
        }
    }
}
