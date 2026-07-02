import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum ChatSubmitPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "paperplane"

    public static let info = LumiPluginInfo(
        id: "ChatSubmit",
        displayName: LumiPluginLocalization.string("Chat Submit", bundle: .module),
        description: LumiPluginLocalization.string("Send or stop chat messages", bundle: .module),
        order: 86
    )
}
