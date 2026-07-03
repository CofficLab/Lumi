import AgentToolKit
import EditorService
import LumiCoreKit
import LumiPreviewKit
import Foundation
import SwiftUI
import os

/// Runtime configuration for inline preview.
public enum EditorPreviewPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "rectangle.inset.filled"

    public static let info = LumiPluginInfo(
        id: "EditorPreview",
        displayName: LumiPluginLocalization.string("Inline Preview", bundle: .module),
        description: LumiPluginLocalization.string("Embedded preview powered by LumiPreviewKit", bundle: .module),
        order: 84
    )
}
