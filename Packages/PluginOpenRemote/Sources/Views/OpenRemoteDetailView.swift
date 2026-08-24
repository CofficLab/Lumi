import AppKit
import LumiUI
import SwiftUI

/// 远程仓库详情视图（在 popover 中显示）
public struct OpenRemoteDetailView: View {
    @LumiTheme private var theme: any LumiUITheme

    public let url: URL?

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "safari")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.primary)

                Text(LumiPluginLocalization.string("远程仓库", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                if let url = url {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text(LumiPluginLocalization.string("打开", bundle: .module))
                        }
                        .font(.appCaption)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            if let url = url {
                // URL 显示
                HStack(spacing: 8) {
                    Text(LumiPluginLocalization.string("URL", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 60, alignment: .leading)

                    Text(url.absoluteString)
                        .font(.appMonoCaption)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer()

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .help(LumiPluginLocalization.string("复制 URL", bundle: .module))
                }
            } else {
                // 无远程仓库
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.appTitle)
                            .foregroundColor(theme.warning)

                        Text(LumiPluginLocalization.string("当前项目没有远程仓库", bundle: .module))
                            .font(.appCallout)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(width: 320)
    }
}