import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

/// 设置界面服务不可用时的整屏错误视图。
///
/// 当 `kernel.settings` / `kernel.theme` 等渲染所必需的内核服务缺失时显示,
/// 取代过去用 `?? []` 静默降级、只显示部分标签的误导性 UI。明确告诉用户
/// 当前内核未就绪(通常是启动初始化失败或设置窗口拿到了空内核实例),
/// 并列出缺失的服务,便于排查。
struct SettingsUnavailableView: View {
    @LumiTheme private var theme

    /// 缺失的必需服务名(用于在错误界面列出)
    let missingServices: [String]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.warning)

            Text(LumiLocalization.string("Settings Unavailable", bundle: .module))
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            Text(LumiLocalization.string(
                "The kernel is not fully initialized. Some required services are missing, so the settings interface cannot be shown. Please restart the app; if the problem persists, check the logs.",
                bundle: .module
            ))
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380)

            if !missingServices.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LumiLocalization.string("Missing services:", bundle: .module))
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textTertiary)

                    ForEach(missingServices, id: \.self) { name in
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(theme.error)
                                .font(.appCaption)
                            Text(name)
                                .font(.appMonoCaption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.error.opacity(0.08))
                )
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
