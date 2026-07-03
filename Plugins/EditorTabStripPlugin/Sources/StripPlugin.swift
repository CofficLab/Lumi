import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum StripHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "rectangle.topthird.inset.filled"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-tab-strip")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-tab-strip-header",
        displayName: LumiPluginLocalization.string("Editor Tab Strip", bundle: .module),
        description: LumiPluginLocalization.string("Tab bar for the editor panel.", bundle: .module),
        order: 70
    )

    @MainActor
    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome else {
            return []
        }

        // LumiEditorServicing 不可用时显示错误视图
        guard let service = context.resolve(LumiEditorServicing.self)?.editorService else {
            return [
                LumiPanelHeaderItem(id: "\(info.id).error", order: info.order) {
                    StripHeaderErrorView(pluginName: info.displayName)
                }
            ]
        }

        return [
            LumiPanelHeaderItem(id: info.id, order: info.order) {
                HeaderView(service: service)
            }
        ]
    }
}
