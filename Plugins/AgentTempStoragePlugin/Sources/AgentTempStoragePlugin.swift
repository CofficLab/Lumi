import LumiKernel
import LumiUI
import SwiftUI

public enum AgentTempStoragePlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.agent-temp-storage",
        displayName: LumiPluginLocalization.string("Agent Temp Storage", bundle: .module),
        description: LumiPluginLocalization.string("Temporary storage for agent data during sessions.", bundle: .module),
        order: 80,
        category: .development,
        policy: .disabled,
        stage: .beta,
        iconName: "archivebox",
    )

    @MainActor
    public static func agentTools(lumiCore: any LumiCoreAccessing) -> [any LumiAgentTool] {
        [
            SaveTempDataTool(),
            LoadTempDataTool(),
            ClearTempDataTool(),
        ]
    }

    @MainActor
    public static func pluginAboutView(lumiCore: any LumiCoreAccessing) -> AnyView? {
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
