import LumiUI
import MagicKit
import SwiftUI
import Foundation
import os

/// 在 Xcode 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 Xcode 中打开当前项目。
actor AgentOpenInXcodePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"

    nonisolated static let verbose: Bool = false

    static let id: String = "AgentOpenInXcode"
    static let displayName: String = String(localized: "Open in Xcode", table: "AgentOpenInXcode")
    static let description: String = String(localized: "Displays a button in the header to open the current project in Xcode", table: "AgentOpenInXcode")
    static let iconName: String = "hammer"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 95 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AgentOpenInXcodePlugin()

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    func addStatusBarLeadingView(activeIcon: String?) -> AnyView? {
        return AnyView(OpenInXcodeStatusBarView())
    }
}

// MARK: - Status Bar View

/// Xcode 打开状态栏视图
struct OpenInXcodeStatusBarView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        Group {
            if projectVM.currentProjectPath.isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInXcodeDetailView(),
            id: "open-in-xcode-status"
        ) {
            Button(action: {
                openInXcode()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "在 Xcode 中打开当前项目", table: "AgentOpenInXcode"))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 10))

            Text(String(localized: "Xcode", table: "OpenInXcodePlugin"))
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(.secondary.opacity(0.5))
        .help(String(localized: "无项目", table: "AgentOpenInXcode"))
    }

    private func openInXcode() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openIn(.xcode)
    }
}

// MARK: - Detail View

/// Xcode 打开详情视图（在 popover 中显示）
struct OpenInXcodeDetailView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 16))

                Text(String(localized: "Xcode", table: "OpenInXcodePlugin"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()

                Button(action: {
                    openInXcode()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text(String(localized: "打开", table: "OpenInXcodePlugin"))
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: 8) {
                Text(String(localized: "项目", table: "OpenInXcodePlugin"))
                    .font(.system(size: 12))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .frame(width: 50, alignment: .leading)

                Text(projectVM.currentProjectPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(projectVM.currentProjectPath, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help(String(localized: "复制路径", table: "OpenInXcodePlugin"))
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func openInXcode() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openIn(.xcode)
    }
}
