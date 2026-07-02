import Foundation
import LumiCoreKit
import SwiftUI
import os

/// 工具调用循环检测插件
public enum ToolCallLoopDetectionPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "arrow.triangle.2.circlepath"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-call-loop-detection")

    public static let info = LumiPluginInfo(
        id: "tool-call-loop-detection",
        displayName: LumiPluginLocalization.string("工具调用循环检测", bundle: .module),
        description: LumiPluginLocalization.string("检测并防止工具调用进入无限循环。", bundle: .module),
        order: 198
    )
}
