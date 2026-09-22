import os
import Foundation
import KitLLM
import KernelCore
import KitSuperLog
import LumiUI
import ProviderLifecycleHooks
import ProviderChatSection
import ProviderProject
import ProviderSettingView
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

    /// `willSendToLLM` 技能注入钩子（见 `Hooks/SkillInjectionHook.swift`）。
    private var skillInjectionHook: SkillInjectionHook?
    private var toolbarViewModel: SkillChatToolbarViewModel?
    private var toolbarObserver: SkillChatToolbarObserver?
    /// 设置页 ViewModel 与观察者（参照 Agent Rules 插件的设置入口模式）。
    private let settingsViewModel = SkillSettingsViewModel()
    private var settingsObserver: SkillSettingsObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        settingsObserver?.cancel()
        settingsObserver = nil
        toolbarObserver?.cancel()
        toolbarObserver = nil
        toolbarViewModel?.cancel()
        toolbarViewModel = nil
        for handle in lifecycleHandles { handle.cancel() }
        lifecycleHandles.removeAll()
        skillInjectionHook = nil

        let project = kernel.resolveProvider((any ProjectProviding).self)
        let skillService = SkillService.shared
        let skillProvider = kernel.resolveProvider((any SkillProviding).self)

        // 1. 设置页入口：展示项目列表 + 每个项目的技能（项目层 + 通用底座）。
        //    与 Agent Rules 插件一致，通过 SettingViewProviding 贡献设置项。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addEntries([
                SettingEntryItem(
                    id: "\(id).settings",
                    title: LumiPluginLocalization.string("Skills", bundle: .module),
                    systemImage: "sparkles",
                    order: order
                ) {
                    SkillSettingsView(viewModel: self.settingsViewModel)
                },
            ])
        }
        if let project {
            settingsObserver = SkillSettingsObserver(
                projectProvider: project,
                skillProvider: skillProvider,
                viewModel: settingsViewModel
            )
        } else {
            Self.logger.warning("\(Self.t)ProjectProviding not registered; skill settings shows no projects")
        }

        // 2. 把内置技能目录作为 contributor 注入 SkillProviding（与插件同通道）。
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

        } else {
            Self.logger.warning("\(Self.t)SkillProviding not registered; degraded to project-level skills only")
        }

        // 3. willSendToLLM 钩子：注入可用技能列表（插件贡献 + 内置 + 项目）。
        //    无当前项目时也注入，保证通用技能始终可用。
        if let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self) {
            let hook = SkillInjectionHook(
                project: project,
                skillProvider: skillProvider,
                skillService: skillService
            )
            skillInjectionHook = hook
            let handle = hooks.addWillSendToLLMHook { [weak hook] context in
                guard let hook else { return context }
                return await hook.apply(to: context)
            }
            lifecycleHandles.append(handle)
        }

        // 4. Chat 工具栏技能入口。
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            let toolbarViewModel = SkillChatToolbarViewModel(service: skillService)
            let toolbarObserver = SkillChatToolbarObserver(
                projectProvider: project,
                skillProvider: skillProvider,
                viewModel: toolbarViewModel
            )
            self.toolbarViewModel = toolbarViewModel
            self.toolbarObserver = toolbarObserver

            chat.addBarItems([
                ChatSectionBarItem(
                    id: "\(id).toolbar",
                    order: 51,
                    placement: .toolbarTrailing
                ) {
                    SkillChatToolbarView(viewModel: toolbarViewModel)
                },
            ])
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        settingsObserver?.cancel()
        settingsObserver = nil
        toolbarObserver?.cancel()
        toolbarObserver = nil
        toolbarViewModel?.cancel()
        toolbarViewModel = nil

        // 撤回 SkillProviding 中的内置 contributor。
        if let skillProvider = kernel.resolveProvider((any SkillProviding).self) {
            skillProvider.removeProvider(providerID: Self.builtinContributorID)
        }

        for handle in lifecycleHandles { handle.cancel() }
        lifecycleHandles.removeAll()
        skillInjectionHook = nil

        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
    }

    private var lifecycleHandles: [any LifecycleHookHandle] = []
}

/// Chat 工具栏技能入口：显示可用技能数量（插件贡献 + 内置 + 项目），点击弹出列表。
///
/// 样式与 ``SpeedToolbarView`` 保持一致。
struct SkillChatToolbarView: View {
    @ObservedObject var viewModel: SkillChatToolbarViewModel

    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .medium))

                if !viewModel.skills.isEmpty {
                    Text("\(viewModel.skills.count)")
                        .font(.system(size: 10, weight: .medium))
                        .contentTransition(.numericText())
                } else {
                    Text(LumiPluginLocalization.string("Skills", bundle: .module))
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Color.accentColor.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(Text(viewModel.skills.isEmpty ? "无可用技能" : "\(viewModel.skills.count) 个可用技能"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            SkillListView(skills: viewModel.skills)
                .frame(width: 320)
                .frame(minHeight: 220, maxHeight: 420)
        }
    }
}
