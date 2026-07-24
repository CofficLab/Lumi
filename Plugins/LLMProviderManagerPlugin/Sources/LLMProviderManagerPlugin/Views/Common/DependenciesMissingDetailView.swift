import LumiKernel
import LumiUI
import SwiftUI

/// 当 settings tab 的依赖缺失时,在详情页底部展示的"为什么不可用"详细说明。
///
/// 渲染 3 个依赖的状态行(LumiKernel / LumiChatServicing / LLMProviderManager),
/// 把缺失的服务用 `×` 标识,保留的服务用 `✓`。下方再附一段修复建议文字,
/// 引导用户排查插件加载顺序、启用状态或外部服务可用性等问题。
///
/// 该视图不依赖 `ProviderDependencySettingsView` —— 它独立消费
/// `SettingsTabDependencyState.Failure`,所以可以单独用在其他场景
/// (例如 `addSettingsView` 或诊断页面)。
struct DependenciesMissingDetailView: View {
    @LumiTheme private var theme

    let failure: SettingsTabDependencyState.Failure

    private struct Dependency: Identifiable {
        let id: String
        let title: String
        let description: String
        let isAvailable: Bool
    }

    private var dependencies: [Dependency] {
        // 按解析顺序标记可用性 —— 一旦某层缺失,后续层默认视为不可用。
        let lumiCoreOK = failure != .missingLumiCore
        let chatServiceOK = lumiCoreOK && failure != .missingChatService
        let managerOK = lumiCoreOK && chatServiceOK && failure != .missingManager

        return [
            Dependency(
                id: "lumiCore",
                title: LumiPluginLocalization.string("settings.dependency.lumiCore.title", bundle: .module),
                description: LumiPluginLocalization.string("settings.dependency.lumiCore.description", bundle: .module),
                isAvailable: lumiCoreOK
            ),
            Dependency(
                id: "chatService",
                title: LumiPluginLocalization.string("settings.dependency.chatService.title", bundle: .module),
                description: LumiPluginLocalization.string("settings.dependency.chatService.description", bundle: .module),
                isAvailable: chatServiceOK
            ),
            Dependency(
                id: "manager",
                title: LumiPluginLocalization.string("settings.dependency.manager.title", bundle: .module),
                description: LumiPluginLocalization.string("settings.dependency.manager.description", bundle: .module),
                isAvailable: managerOK
            ),
        ]
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: true, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 18) {
                headerTitle
                dependencyList
                suggestion
            }
        }
    }

    private var headerTitle: some View {
        // 顶部说明 —— 解释为什么用户能看到这个 tab 但内容不可用。
        Text(LumiPluginLocalization.string("settings.dependency.requiredServices", bundle: .module))
            .font(.appSectionTitle)
            .foregroundStyle(theme.textPrimary)
    }

    private var dependencyList: some View {
        VStack(spacing: 0) {
            ForEach(dependencies) { dep in
                dependencyRow(dep)
                if dep.id != dependencies.last?.id {
                    AppDivider()
                        .padding(.leading, 44)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 1)
        )
    }

    private func dependencyRow(_ dependency: Dependency) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: dependency.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(dependency.isAvailable ? theme.success : theme.error)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(dependency.title)
                    .font(.appBodyEmphasized)
                    .foregroundStyle(theme.textPrimary)

                Text(dependency.description)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(
                LumiPluginLocalization.string(
                    dependency.isAvailable ? "settings.dependency.statusAvailable" : "settings.dependency.statusMissing",
                    bundle: .module
                )
            )
            .font(.appMicro)
            .foregroundStyle(dependency.isAvailable ? theme.success : theme.error)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill((dependency.isAvailable ? theme.success : theme.error).opacity(0.12))
            )
        }
        .padding(.vertical, 10)
    }

    private var suggestion: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LumiPluginLocalization.string("settings.dependency.suggestion.title", bundle: .module))
                .font(.appBodyEmphasized)
                .foregroundStyle(theme.textPrimary)

            Text(failureSuggestionText)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.appAccentSoftFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.25), lineWidth: 1)
        )
    }

    private var failureSuggestionText: String {
        switch failure {
        case .missingLumiCore:
            return LumiPluginLocalization.string(
                "settings.dependency.suggestion.missingLumiCore",
                bundle: .module
            )
        case .missingChatService:
            return LumiPluginLocalization.string(
                "settings.dependency.suggestion.missingChatService",
                bundle: .module
            )
        case .missingManager:
            return LumiPluginLocalization.string(
                "settings.dependency.suggestion.missingManager",
                bundle: .module
            )
        }
    }
}
