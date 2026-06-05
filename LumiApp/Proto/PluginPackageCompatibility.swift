import LumiCoreKit
import EditorService
import Combine
import SwiftUI

extension PluginCategory {
    init(package value: LumiCoreKit.PluginCategory) {
        self = PluginCategory(rawValue: value.rawValue) ?? .general
    }
}

extension RailItem {
    init(package item: LumiCoreKit.RailItem) {
        self.init(
            id: item.id,
            title: item.title,
            systemImage: item.systemImage,
            priority: item.priority,
            makeView: item.makeView
        )
    }
}

extension SidebarToolbarItem {
    init(package item: LumiCoreKit.SidebarToolbarItem) {
        self.init(
            id: item.id,
            title: item.title,
            systemImage: item.systemImage,
            priority: item.priority
        )
    }
}

extension BottomPanelTab {
    init(package item: LumiCoreKit.BottomPanelTab) {
        self.init(
            id: item.id,
            title: item.title,
            systemImage: item.systemImage,
            priority: item.priority
        )
    }
}

extension ViewContainerItem {
    init(package item: LumiCoreKit.ViewContainerItem) {
        self.init(
            id: item.id,
            title: item.title,
            icon: item.icon,
            showsProjectToolbar: item.showsProjectToolbar,
            showChat: item.showChat,
            showsRail: item.showsRail,
            showsBottomPanel: item.showsBottomPanel,
            makeView: item.makeView
        )
    }
}

extension ToolContext {
    var packageContext: LumiCoreKit.ToolContext {
        let packageLLMService = llmService.map { service in
            LumiCoreKit.LLMService(
                sendMessageHandler: { messages, config, tools in
                    try await service.sendMessage(messages: messages, config: config, tools: tools)
                },
                providersProvider: {
                    service.allProviders()
                },
                providerTypeProvider: { providerId in
                    service.providerType(forId: providerId)
                },
                providerFactory: { providerId in
                    service.createProvider(id: providerId)
                },
                apiKeyProvider: { [llmVM] providerId in
                    llmVM?.getApiKey(for: providerId) ?? ""
                }
            )
        }

        let packageLLMVM = llmVM.map { vm in
            let packageVM = LumiCoreKit.AppLLMVM(
                selectedProviderId: vm.selectedProviderId,
                currentModel: vm.currentModel,
                isAutoMode: vm.isAutoMode,
                lastAutoRouteSummary: vm.lastAutoRouteSummary,
                chatMode: LumiCoreKit.ChatMode(rawValue: vm.chatMode.rawValue) ?? .build,
                llmService: packageLLMService ?? LumiCoreKit.LLMService(),
                providersProvider: {
                    vm.allProviders
                },
                providerTypeProvider: { providerId in
                    vm.providerType(forId: providerId)
                },
                providerFactory: { providerId in
                    vm.createProvider(id: providerId)
                },
                apiKeyProvider: { providerId in
                    vm.getApiKey(for: providerId)
                },
                selectedProviderIdSetter: { providerId in
                    vm.selectedProviderId = providerId
                },
                currentModelSetter: { model in
                    vm.currentModel = model
                },
                isAutoModeSetter: { isAutoMode in
                    vm.isAutoMode = isAutoMode
                },
                chatModeSetter: { mode in
                    guard let appMode = ChatMode(rawValue: mode.rawValue) else { return }
                    vm.setChatMode(appMode)
                }
            )
            packageVM.retainHostStateSubscription(
                vm.$selectedProviderId.sink { [weak packageVM] providerId in
                    Task { @MainActor in
                        packageVM?.updateSelectedProviderIdFromHost(providerId)
                    }
                }
            )
            packageVM.retainHostStateSubscription(
                vm.$currentModel.sink { [weak packageVM] model in
                    Task { @MainActor in
                        packageVM?.updateCurrentModelFromHost(model)
                    }
                }
            )
            packageVM.retainHostStateSubscription(
                vm.$isAutoMode.sink { [weak packageVM] isAutoMode in
                    Task { @MainActor in
                        packageVM?.updateIsAutoModeFromHost(isAutoMode)
                    }
                }
            )
            packageVM.retainHostStateSubscription(
                vm.$lastAutoRouteSummary.sink { [weak packageVM] summary in
                    Task { @MainActor in
                        packageVM?.updateLastAutoRouteSummaryFromHost(summary)
                    }
                }
            )
            return packageVM
        }

        let packageToolService = LumiCoreKit.ToolService(
            tools: toolService.tools,
            executeToolHandler: { [toolService] name, argumentsJSON, executionContext in
                try await toolService.executeTool(
                    named: name,
                    argumentsJSON: argumentsJSON,
                    context: executionContext
                )
            },
            registerProgressSnapshotProviderHandler: { [toolService] toolName, provider in
                toolService.registerProgressSnapshotProvider(for: toolName, provider: provider)
            }
        )

        let packageConversationVM = conversationVM.map { vm in
            LumiCoreKit.WindowConversationVM(
                selectedConversationId: vm.selectedConversationId,
                currentPreferenceProvider: {
                    vm.getModelPreference().map { ($0.providerId, $0.model) }
                },
                preferenceProvider: { conversationId in
                    vm.getModelPreference(for: conversationId).map { ($0.providerId, $0.model) }
                },
                preferenceSaver: { conversationId, providerId, model in
                    if let conversationId {
                        vm.saveModelPreference(for: conversationId, providerId: providerId, model: model)
                    } else {
                        vm.saveModelPreference(providerId: providerId, model: model)
                    }
                },
                chatModePreferenceProvider: {
                    vm.getChatModePreference().flatMap { LumiCoreKit.ChatMode(rawValue: $0.rawValue) }
                }
            )
        }

        let packageRecentProjectsVM = recentProjectsVM.map { vm in
            LumiCoreKit.AppProjectsVM(
                recentProjects: vm.recentProjects.map {
                    LumiCoreKit.Project(name: $0.name, path: $0.path, lastUsed: $0.lastUsed)
                }
            )
        }

        return LumiCoreKit.ToolContext(
            languagePreference: languagePreference,
            llmService: packageLLMService,
            toolService: packageToolService,
            llmVM: packageLLMVM,
            conversationVM: packageConversationVM,
            conversationListContext: conversationListContext,
            currentProjectName: currentProjectName,
            currentProjectPath: currentProjectPath,
            recentProjectsVM: packageRecentProjectsVM
        )
    }
}

struct PackageMessageRendererAdapter: SuperMessageRenderer {
    private let renderer: any LumiCoreKit.SuperMessageRenderer

    init(_ renderer: any LumiCoreKit.SuperMessageRenderer) {
        self.renderer = renderer
    }

    static var id: String { "package-message-renderer" }
    static var priority: Int { 0 }
    var rendererID: String { renderer.rendererID }
    var rendererPriority: Int { renderer.rendererPriority }

    func canRender(message: ChatMessage) -> Bool {
        renderer.canRender(message: message)
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        renderer.render(message: message, showRawMessage: showRawMessage)
    }
}
