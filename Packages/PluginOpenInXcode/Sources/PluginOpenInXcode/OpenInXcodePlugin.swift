import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderDocsView
import ProviderToolManager
import ProviderToolbar
import SwiftUI

/// 在 Xcode 中打开项目的插件。
@MainActor
public final class OpenInXcodePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-xcode", category: "OpenInXcode")

    public let id = "com.coffic.lumi.plugin.open-in-xcode"
    public let order = 611
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-xcode",
        name: OpenInXcodeLocalization.string("Open In Xcode"),
        description: OpenInXcodeLocalization.string("Allow LLM to open projects in Xcode."),
        category: .integration,
        stage: .stable,
        policy: .disabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                OpenInAboutView(displayName: OpenInTool.xcode.displayName, systemImage: OpenInTool.xcode.systemImage, toolName: OpenInTool.xcode.toolName)
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                OpenInManualView(displayName: OpenInTool.xcode.displayName, toolName: OpenInTool.xcode.toolName)
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let tool = OpenInTool(config: OpenInTool.xcode, project: project)

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: OpenInXcodeLocalization.string("Open In Xcode"),
                    placement: .leading,
                    category: .global,
                    order: order
                ) {
                    OpenInXcodeToolbarView(tool: tool, project: project)
                },
            ])
        }

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }

        toolManager.add(tool, pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).toolbar"])

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        toolManager.remove(id: OpenInTool.xcode.toolName)
    }
}

/// Open In Xcode 的标题栏按钮。
@MainActor
private struct OpenInXcodeToolbarView: View {
    @StateObject private var model: OpenInXcodeToolbarModel

    init(tool: OpenInTool, project: (any ProjectProviding)?) {
        _model = StateObject(wrappedValue: OpenInXcodeToolbarModel(tool: tool, project: project))
    }

    var body: some View {
        Button {
            model.openProjectInXcode()
        } label: {
            Image(systemName: OpenInTool.xcode.systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isOpening || model.currentProjectPath == nil)
        .help(OpenInXcodeLocalization.string("Open In Xcode"))
        .opacity(model.isOpening ? 0.5 : 1)
        .onDisappear {
            model.cancel()
        }
    }
}

/// 为标题栏按钮提供当前项目状态，并在项目切换后刷新可用性。
@MainActor
private final class OpenInXcodeToolbarModel: ObservableObject {
    let tool: OpenInTool
    private var projectObserver: (any ProjectProvidingObserverHandle)?

    @Published private(set) var currentProjectPath: String?
    @Published private(set) var isOpening = false

    init(tool: OpenInTool, project: (any ProjectProviding)?) {
        self.tool = tool
        self.currentProjectPath = project?.currentProject?.path
        self.projectObserver = project?.addObserver { [weak self] event in
            guard case let .currentProjectChanged(currentProject, _) = event else { return }
            self?.currentProjectPath = currentProject?.path
        }
    }

    func cancel() {
        projectObserver?.cancel()
        projectObserver = nil
    }

    func openProjectInXcode() {
        guard !isOpening, currentProjectPath != nil else { return }
        isOpening = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isOpening = false }
            do {
                _ = try await tool.execute(arguments: [:])
            } catch {
                OpenInXcodePlugin.logger.error("\(OpenInXcodePlugin.t)Failed to open project in Xcode: \(error.localizedDescription)")
            }
        }
    }
}
