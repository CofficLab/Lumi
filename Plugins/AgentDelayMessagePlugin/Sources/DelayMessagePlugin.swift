import LumiCoreKit
import LumiUI
import SwiftUI
import os

/// 延时消息插件：在未来某个时刻自动恢复对话。
public enum DelayMessagePlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.delay-message")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.delay-message",
        displayName: LumiPluginLocalization.string("Delay Message", bundle: .module),
        description: LumiPluginLocalization.string("Schedule delayed messages to resume conversations automatically.", bundle: .module),
        order: 98,
        category: .agent,
        policy: .disabled,
        stage: .beta,
        iconName: "clock.badge",
    )

    @MainActor
    public static func agentTools(context: any LumiCoreAccessing) -> [any LumiAgentTool] {
        [DelayMessageTool()]
    }

        @MainActor
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

}
