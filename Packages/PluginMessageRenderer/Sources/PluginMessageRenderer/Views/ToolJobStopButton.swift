import LumiUI
import ProviderToolManager
import SwiftUI

struct ToolJobStopButton: View {
    @LumiTheme private var theme

    let model: ToolJobActivityModel

    var body: some View {
        AppIconButton(
            systemImage: "stop.fill",
            tint: theme.error,
            size: .compact
        ) {
            model.cancel()
        }
        .help("停止工具")
    }
}
