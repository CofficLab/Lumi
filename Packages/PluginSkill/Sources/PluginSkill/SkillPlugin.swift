import os
import Foundation
import KitLLM
import KernelCore
import KitSuperLog
import ProviderLifecycleHooks
import ProviderChatSection
import ProviderProject
import ProviderSkill
import SwiftUI

/// 技能插件：聚合「插件贡献 + 内置 + 项目」三层技能并注入 LLM system prompt。
///
/// - 作为 `SkillProviding` 的消费方 + 贡献者：
///   - 在 `onBoot` 解析内核 `SkillProviding`，把随包的内置技能目录
///     （`BuiltinSkills/`）作为 contributor 注入——与其它插件贡献技能同通道；
///   - 向 AgentLoop 注册 `willSendToLLM` 钩子：读取 Provider 的
///     「插件贡献 + 内置」底座，交给 `SkillService` 叠加项目层后注入
///     瞬态 system 消息（不落库，仅本次请求生效）；
///   - 在 Chat 工具栏注册技能入口（无项目 / 无技能时自动隐藏）。
@MainActor
public final class SkillPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.skill", category: "Skill")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.skill"
    public let order = 51
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.skill",
        name: "Skill",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    /// 内置技能 contributor 的 providerID。公开以便测试断言。
    public static let builtinContributorID = "com.coffic.lumi.plugin.skill.builtin"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ProjectProviding from kernel")
            return
        }
        let skillService = SkillService.shared
        let skillProvider = kernel.resolveProvider((any SkillProviding).self)

        // 1. 把内置技能目录作为 contributor 注入 SkillProviding（与插件同通道）。
        //    若 Provider 未装配（如测试环境），降级：不带内置目录，仅依赖项目层。
        if let skillProvider {
            if !skillProvider.isProviderRegistered(providerID: Self.builtinContributorID) {
                let builtinSkills = BuiltinSkillCatalog.shared.builtinSkills()
                let builtinContributor = StaticSkillContributor(
                    providerID: Self.builtinContributorID,
                    skills: builtinSkills
                )
                skillProvider.addProvider(builtinContributor)
            }

            // 缓存失效：插件贡献变化时刷新 SkillService 缓存。
            let handle = skillProvider.addObserver { [weak skillService] _ in
                Task { await skillService?.invalidateAllCache() }
            }
            observerHandles.append(handle)
        } else {
            Self.logger.warning("\(Self.t)SkillProviding not registered; degraded to project-level skills only")
        }

        // 2. willSendToLLM 钩子：注入可用技能列表（插件贡献 + 内置 + 项目）。
        //    无当前项目时也注入，保证通用技能始终可用。
        if let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self) {
            let handle = hooks.addWillSendToLLMHook { [weak project, weak skillProvider] context in
                let projectPath = project?.currentProject?.path ?? ""
                // 底座 = 插件贡献 + 内置（由 SkillProviding 聚合）。
                let baseSkills = skillProvider?.allSkills() ?? []
                let skills = await skillService.listSkills(projectPath: projectPath, baseSkills: baseSkills)
                guard !skills.isEmpty else { return context }
                let prompt = SkillPromptBuilder.buildPrompt(skills: skills)
                var ctx = context
                ctx.messages = [LLMMessage(role: .system, content: prompt)] + ctx.messages
                return ctx
            }
            lifecycleHandles.append(handle)
        }

        // 3. Chat 工具栏技能入口。
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            chat.addBarItems([
                ChatSectionBarItem(
                    id: "\(id).toolbar",
                    order: 51,
                    placement: .toolbarTrailing
                ) {
                    SkillChatToolbarView(project: project, skillService: skillService, skillProvider: skillProvider)
                },
            ])
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回 SkillProviding 中的内置 contributor。
        if let skillProvider = kernel.resolveProvider((any SkillProviding).self) {
            skillProvider.removeProvider(providerID: Self.builtinContributorID)
        }

        for handle in lifecycleHandles { handle.cancel() }
        lifecycleHandles.removeAll()
        for handle in observerHandles { handle.cancel() }
        observerHandles.removeAll()

        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
    }

    private var lifecycleHandles: [any LifecycleHookHandle] = []
    private var observerHandles: [any SkillProvidingObserverHandle] = []
}

/// Chat 工具栏技能入口：显示可用技能数量（插件贡献 + 内置 + 项目），点击弹出列表。
struct SkillChatToolbarView: View {
    let project: any ProjectProviding
    let skillService: SkillService
    let skillProvider: (any SkillProviding)?

    @State private var isPopoverPresented = false
    @State private var skills: [SkillMetadata] = []

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                if !skills.isEmpty {
                    Text("\(skills.count)")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(skills.isEmpty ? "无可用技能" : "\(skills.count) 个可用技能")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LumiPluginLocalization.string("Skills", bundle: .module))
                    .font(.system(size: 12, weight: .semibold))
                if skills.isEmpty {
                    Text("当前没有可用技能")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(skills, id: \.id) { skill in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentColor)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(skill.title)
                                            .font(.system(size: 11, weight: .medium))
                                        Text(skill.description)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                        }
                    }
                    .frame(maxHeight: 240)
                }
            }
            .padding(10)
            .frame(width: 280)
        }
        .task {
            await refresh()
        }
        .onChange(of: project.currentProject?.path) { _, _ in
            Task { @MainActor in
                await refresh()
            }
        }
    }

    private func refresh() async {
        let path = project.currentProject?.path ?? ""
        let baseSkills = skillProvider?.allSkills() ?? []
        skills = await skillService.listSkills(projectPath: path, baseSkills: baseSkills)
    }
}