import LumiUI
import SwiftUI

struct GeneralSettingsPage: View {
    @State private var reopenLastWindow = true
    @State private var enableStatusBar = true
    @State private var showDeveloperCommands = true

    var body: some View {
        SettingsPageScaffold(title: "通用", subtitle: "基础应用行为") {
            AppSettingsSection(title: "启动") {
                AppSettingsToggleRow(
                    "恢复上次窗口",
                    description: "保留入口，后续接入窗口持久化服务。",
                    systemImage: "macwindow",
                    isOn: $reopenLastWindow
                )
            }

            AppSettingsSection(title: "界面") {
                AppSettingsToggleRow(
                    "显示状态栏",
                    description: "当前为只读布局开关占位。",
                    systemImage: "rectangle.bottomthird.inset.filled",
                    isOn: $enableStatusBar
                )
                AppSettingsToggleRow(
                    "显示调试命令",
                    description: "调试菜单已经恢复，这里先保留设置项。",
                    systemImage: "ladybug",
                    isOn: $showDeveloperCommands
                )
            }
        }
    }
}
