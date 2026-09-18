import LumiUI
import SwiftUI

/// ACP 接入引导设置页。
///
/// 教用户如何把 Lumi 的 ACP（Agent Client Protocol）能力接入支持该协议的外部
/// 编辑器（VS Code / Zed 等）：构建 headless 入口、指向编辑器、验证握手。
/// 纯静态教程页，不持有插件状态。
@MainActor
struct ACPSettingsView: View {
    @LumiTheme private var theme

    var body: some View {
        PluginSettingsScaffold(
            title: ACPLocalization.string("ACP"),
            subtitle: ACPLocalization.string("Connect Lumi to external editors")
        ) {
            whatIsSection
            prerequisitesSection
            stepsSection
            verifySection
            notesSection
        }
    }

    // MARK: - What is ACP

    private var whatIsSection: some View {
        AppCard {
            AppSettingsSection(title: ACPLocalization.string("What is ACP")) {
                Text(ACPLocalization.string("ACP lets supported editors (VS Code, Zed, and more) run Lumi as their built-in coding agent over stdio, reusing Lumi's model routing, tool system, and project intelligence."))
                    .font(.appBody)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Prerequisites

    private var prerequisitesSection: some View {
        AppCard {
            AppSettingsSection(title: ACPLocalization.string("Prerequisites")) {
                VStack(alignment: .leading, spacing: 8) {
                    prerequisiteRow("macOS 14 or later.")
                    prerequisiteRow("Xcode Command Line Tools with swift available on PATH.")
                    prerequisiteRow("A model and API key configured in Lumi — the headless process reuses the app's Keychain.")
                }
            }
        }
    }

    private func prerequisiteRow(_ key: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
                .frame(width: 14, height: 14)
                .padding(.top, 2)
            Text(ACPLocalization.string(key))
                .font(.appBody)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        AppCard {
            AppSettingsSection(title: ACPLocalization.string("Steps")) {
                VStack(alignment: .leading, spacing: 18) {
                    stepBlock(
                        index: 1,
                        title: ACPLocalization.string("Build the headless entry point"),
                        body: ACPLocalization.string("In the Lumi repository run:")
                    )
                    codeBlock("swift build --package-path Packages/ACPBootstrap")
                    Text(ACPLocalization.string("The binary lands at Packages/ACPBootstrap/.build/debug/ACPBootstrap."))
                        .font(.appBody)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    stepBlock(
                        index: 2,
                        title: ACPLocalization.string("Point your editor at the binary"),
                        body: ACPLocalization.string("In any editor with Agent Client Protocol support, set the agent command to the path above. When the embedded agent ships inside Lumi.app, use /Applications/Lumi.app/Contents/MacOS/lumi-acp.")
                    )

                    stepBlock(
                        index: 3,
                        title: ACPLocalization.string("Start a conversation"),
                        body: ACPLocalization.string("Create a new ACP session in the editor and send a prompt. Lumi runs the turn and streams updates back to the editor.")
                    )
                }
            }
        }
    }

    private func stepBlock(index: Int, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(theme.primary, in: Circle())
                Text(title)
                    .font(.appBodyEmphasized)
                    .foregroundStyle(theme.textPrimary)
            }
            Text(body)
                .font(.appBody)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func codeBlock(_ command: String) -> some View {
        Text(command)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(theme.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.divider, lineWidth: 0.5)
            }
    }

    // MARK: - Verify

    private var verifySection: some View {
        AppCard {
            AppSettingsSection(title: ACPLocalization.string("Verify the connection")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(ACPLocalization.string("In the Lumi repository run:"))
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                    codeBlock(#"echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{}}}' | swift run --package-path Packages/ACPBootstrap"#)
                    Text(ACPLocalization.string("A JSON-RPC response with protocolVersion 1 and agentInfo.name \"lumi-acp\" means the handshake succeeded."))
                        .font(.appBody)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        AppCard {
            AppSettingsSection(title: ACPLocalization.string("Notes")) {
                VStack(alignment: .leading, spacing: 10) {
                    noteRow("The Lumi app never auto-starts the ACP server — stdin belongs to the editor. Only the headless entry point serves the protocol.")
                    noteRow("Tool approvals appear as permission prompts inside the editor.")
                }
            }
        }
    }

    private func noteRow(_ key: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(theme.textSecondary)
                .frame(width: 14, height: 14)
                .padding(.top, 2)
            Text(ACPLocalization.string(key))
                .font(.appBody)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
