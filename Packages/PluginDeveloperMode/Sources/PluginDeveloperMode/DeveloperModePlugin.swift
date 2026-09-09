import KernelCore
import KitSuperLog
import LumiUI
import os
import ProviderDeveloperMode
import ProviderToolbar
import SwiftUI

/// Provides the runtime developer-mode switch and its toolbar control.
@MainActor
public final class DeveloperModePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.developer-mode",
        category: "DeveloperMode"
    )

    public let id = "com.coffic.lumi.plugin.developer-mode"
    public let order = 1

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.developer-mode",
        name: "Developer Mode",
        description: "Runtime controls for development-only diagnostics",
        category: .general,
        stage: .stable,
        policy: .alwaysOn
    )

    private var provider: (any DeveloperModeProviding)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let provider: any DeveloperModeProviding
        if let existing = kernel.resolveProvider((any DeveloperModeProviding).self) {
            provider = existing
        } else {
            let defaultProvider = DefaultDeveloperModeProviding()
            try kernel.registerProvider((any DeveloperModeProviding).self, defaultProvider)
            provider = defaultProvider
        }
        self.provider = provider

        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolbarProviding from kernel")
            return
        }

        toolbar.addToolbarItems([
            ToolbarItem(
                id: "\(id).toggle",
                title: LumiPluginLocalization.string("Developer mode"),
                placement: .leading,
                category: .global,
                order: 5
            ) {
                DeveloperModeToggleView(provider: provider)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(
            ids: ["\(id).toggle"]
        )
        provider = nil
    }
}

private struct DeveloperModeToggleView: View {
    @LumiTheme private var theme
    @StateObject private var observation: DeveloperModeObservation

    private let provider: any DeveloperModeProviding

    init(provider: any DeveloperModeProviding) {
        self.provider = provider
        _observation = StateObject(
            wrappedValue: DeveloperModeObservation(provider: provider)
        )
    }

    var body: some View {
        Button {
            provider.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: observation.isEnabled ? "hammer.fill" : "hammer")
                Text(LumiPluginLocalization.string("DEV"))
            }
            .font(.appMicroEmphasized)
            .tracking(0.3)
            .foregroundStyle(observation.isEnabled ? .white : theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                observation.isEnabled
                    ? theme.warning
                    : theme.textSecondary.opacity(0.12),
                in: Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(
            LumiPluginLocalization.string(
                observation.isEnabled ? "Developer mode is enabled" : "Developer mode is disabled"
            )
        )
        .accessibilityLabel(LumiPluginLocalization.string("Developer mode"))
        .accessibilityValue(
            LumiPluginLocalization.string(
                observation.isEnabled ? "Developer mode is enabled" : "Developer mode is disabled"
            )
        )
    }
}
