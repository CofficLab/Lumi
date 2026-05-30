import AgentToolKit
import Foundation
import LumiCoreKit
import PluginAgentLanguage
import SuperLogKit
import SwiftUI
import os

actor AgentLanguagePlugin: SuperPlugin {
    nonisolated static let emoji = PluginAgentLanguage.AgentLanguagePlugin.emoji
    nonisolated static let verbose = PluginAgentLanguage.AgentLanguagePlugin.verbose
    static let id = PluginAgentLanguage.AgentLanguagePlugin.id
    static let displayName = PluginAgentLanguage.AgentLanguagePlugin.displayName
    static let description = PluginAgentLanguage.AgentLanguagePlugin.description
    static let iconName = PluginAgentLanguage.AgentLanguagePlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginAgentLanguage.AgentLanguagePlugin.category) }
    static var order: Int { PluginAgentLanguage.AgentLanguagePlugin.order }
    static let shared = AgentLanguagePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(LanguageSendMiddleware())]
    }

    @MainActor
    func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        PluginAgentLanguage.AgentLanguagePlugin.shared.addSidebarLeadingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor
    func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "language-toggle" else { return nil }
        return AnyView(LanguageToggleButton())
    }
}

@MainActor
private final class LanguageSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = true
    let id: String = "language-preference"
    let order: Int = -10

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let preference = ctx.projectVM.languagePreference
        if Self.verbose {
            Logger(subsystem: "com.coffic.lumi", category: "middleware.language")
                .info("🌐 语言中间件：注入 \(preference.displayName)")
        }
        ctx.transientSystemPrompts.append(preference.systemPromptDescription)
        await next(ctx)
    }
}

private struct LanguageToggleButton: View {
    @EnvironmentObject private var projectVM: WindowProjectVM

    private static let languageOrder: [LanguagePreference] = [.chinese, .english]

    var body: some View {
        Button(action: {
            let currentIndex = Self.languageOrder.firstIndex(of: projectVM.languagePreference) ?? 0
            let nextIndex = (currentIndex + 1) % Self.languageOrder.count
            let newLanguage = Self.languageOrder[nextIndex]
            withAnimation {
                projectVM.setLanguagePreference(newLanguage)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: projectVM.languagePreference.iconName)
                    .font(.system(size: 13))
                Text(projectVM.languagePreference.shortDisplayName)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var foregroundColor: Color {
        switch projectVM.languagePreference {
        case .chinese:
            Color.blue
        case .english:
            Color.purple
        }
    }

    private var backgroundColor: Color {
        switch projectVM.languagePreference {
        case .chinese:
            Color.blue.opacity(0.1)
        case .english:
            Color.purple.opacity(0.1)
        }
    }

    private var helpText: String {
        switch projectVM.languagePreference {
        case .chinese:
            "当前：中文，点击切换为英文"
        case .english:
            "Current: English, click to switch to Chinese"
        }
    }
}

private extension LanguagePreference {
    var shortDisplayName: String {
        switch self {
        case .chinese: "中"
        case .english: "EN"
        }
    }

    var iconName: String {
        switch self {
        case .chinese: "character.book.closed"
        case .english: "textformat.abc"
        }
    }
}
