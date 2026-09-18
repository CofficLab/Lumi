import AppKit
import LumiUI
import SwiftUI

// MARK: - Data Models

fileprivate struct ACPGuideStep: Identifiable {
    let id = UUID()
    let titleKey: String
    let bodyKey: String
    let code: String?
}

fileprivate struct ACPAppGuide: Identifiable {
    let id: String
    let name: String
    let systemImage: String
    let requirementKey: String
    let summaryKey: String
    let steps: [ACPGuideStep]
}

/// ACP 接入引导设置页。
///
/// 列出支持 ACP 的编辑器（Xcode / Zed），每张卡片点击后弹出逐步配置引导 modal。
/// ACP 二进制随 Lumi.app 内嵌分发（Contents/MacOS/lumi-acp），用户无需手动构建。
/// 将来加入其他 app 只需往 `appGuides` 数组追加一项。纯静态教程页，不持有插件状态。
@MainActor
struct ACPSettingsView: View {
    @LumiTheme private var theme
    @State private var activeGuide: ACPAppGuide?
    @State private var pathCopied = false

    private var helperPath: String {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent("lumi-acp")
            .path
    }

    var body: some View {
        PluginSettingsScaffold(
            title: ACPLocalization.string("ACP"),
            subtitle: ACPLocalization.string("Connect Lumi to external editors")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                helperPathCard
                ForEach(appGuides) { guide in
                    appGuideCard(guide)
                }
            }
        }
        .sheet(item: $activeGuide) { guide in
            ACPGuideSetupSheetView(guide: guide)
        }
    }

    // MARK: - Helper Path

    private var helperPathCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(ACPLocalization.string("ACP executable path"))
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textSecondary)
                Text(helperPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(theme.divider, lineWidth: 0.5)
                    }
                Button {
                    copyHelperPath()
                } label: {
                    Label(
                        pathCopied ? ACPLocalization.string("Copied") : ACPLocalization.string("Copy ACP path"),
                        systemImage: pathCopied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.appBodyEmphasized)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func copyHelperPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(helperPath, forType: .string)
        pathCopied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            pathCopied = false
        }
    }

    // MARK: - App Guides

    private let appGuides: [ACPAppGuide] = [
        ACPAppGuide(
            id: "xcode",
            name: "Xcode",
            systemImage: "hammer",
            requirementKey: "Xcode 27+",
            summaryKey: "Use Lumi as a coding agent inside Xcode via the Agent Client Protocol.",
            steps: [
                ACPGuideStep(
                    titleKey: "Open Intelligence settings",
                    bodyKey: "In Xcode, choose Xcode > Settings, then select Intelligence.",
                    code: nil
                ),
                ACPGuideStep(
                    titleKey: "Add an agent",
                    bodyKey: "Under Agents, click Add an Agent.",
                    code: nil
                ),
                ACPGuideStep(
                    titleKey: "Point to the Lumi binary",
                    bodyKey: "Set Executable to the lumi-acp path copied from Lumi settings; leave Arguments empty.",
                    code: nil
                ),
                ACPGuideStep(
                    titleKey: "Start using Lumi",
                    bodyKey: "Click Add, then choose the agent in a new conversation. Xcode 27 is in beta; ACP integration is early.",
                    code: nil
                ),
            ]
        ),
        ACPAppGuide(
            id: "zed",
            name: "Zed",
            systemImage: "text.cursor",
            requirementKey: "Recent Zed release",
            summaryKey: "Use Lumi as an external agent in Zed's Agent Panel via ACP.",
            steps: [
                ACPGuideStep(
                    titleKey: "Open agent settings",
                    bodyKey: "Open the command palette (Cmd+Shift+P), search for and run \"agent: open settings\".",
                    code: nil
                ),
                ACPGuideStep(
                    titleKey: "Add a custom agent",
                    bodyKey: "Click Add Agent, then choose Add Custom Agent.",
                    code: nil
                ),
                ACPGuideStep(
                    titleKey: "Configure the agent server",
                    bodyKey: "Add the following to agent_servers in settings.json, replacing the command with the lumi-acp path copied from Lumi settings:",
                    code: "{\n  \"agent_servers\": {\n    \"Lumi\": {\n      \"type\": \"custom\",\n      \"command\": \"/Applications/Lumi.app/Contents/MacOS/lumi-acp\",\n      \"args\": [],\n      \"env\": {}\n    }\n  }\n}"
                ),
                ACPGuideStep(
                    titleKey: "Start using Lumi",
                    bodyKey: "Open the Agent Panel, start a new thread, and select Lumi.",
                    code: nil
                ),
            ]
        ),
    ]

    private func appGuideCard(_ guide: ACPAppGuide) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: guide.systemImage)
                        .foregroundStyle(theme.primary)
                        .frame(width: 18, height: 18)
                    Text(guide.name)
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 8)
                    Text(ACPLocalization.string(guide.requirementKey))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                Text(ACPLocalization.string(guide.summaryKey))
                    .font(.appBody)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    activeGuide = guide
                } label: {
                    Text(ACPLocalization.string("Show setup steps"))
                        .font(.appBodyEmphasized)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
            }
        }
    }
}

// MARK: - Setup Sheet

@MainActor
private struct ACPGuideSetupSheetView: View {
    let guide: ACPAppGuide
    @Environment(\.dismiss) private var dismiss
    @LumiTheme private var theme
    @State private var stepIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                stepContent
                    .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 540, height: 480)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: guide.systemImage)
                .foregroundStyle(theme.primary)
            Text(guide.name)
                .font(.appBodyEmphasized)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button(ACPLocalization.string("Done")) {
                dismiss()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var stepContent: some View {
        let step = guide.steps[stepIndex]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, _ in
                    Circle()
                        .fill(index == stepIndex ? theme.primary : theme.divider)
                        .frame(width: 8, height: 8)
                }
            }
            Text("Step \(stepIndex + 1) / \(guide.steps.count)")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            Text(ACPLocalization.string(step.titleKey))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Text(ACPLocalization.string(step.bodyKey))
                .font(.appBody)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let code = step.code {
                codeBlock(code)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(ACPLocalization.string("Previous")) {
                stepIndex -= 1
            }
            .disabled(stepIndex == 0)
            .buttonStyle(.bordered)
            Spacer()
            if stepIndex < guide.steps.count - 1 {
                Button(ACPLocalization.string("Next")) {
                    stepIndex += 1
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
            } else {
                Button(ACPLocalization.string("Done")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
}
