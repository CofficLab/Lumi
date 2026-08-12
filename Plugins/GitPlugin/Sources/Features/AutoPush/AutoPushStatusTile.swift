import SwiftUI
import LumiUI
import LumiKernel

/// Auto Push 状态磁贴：开关 + 当前运行状态。
public struct AutoPushStatusTile: View {
    @ObservedObject var service: AutoPushService
    let onTap: () -> Void
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init(service: AutoPushService = .shared, onTap: @escaping () -> Void) {
        self.service = service
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: service.isRunning
                      ? "arrow.up.to.line.circle.fill"
                      : "arrow.up.to.line.circle")
                    .font(.appMicroEmphasized)
                    .foregroundStyle(service.config.enabled
                                     ? (service.isRunning ? theme.success : theme.primary)
                                     : theme.textTertiary)
                Text(service.isRunning ? "Auto" : "Off")
                    .font(.appMicroEmphasized)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(LumiPluginLocalization.string("Auto Push", bundle: .module))
    }
}
